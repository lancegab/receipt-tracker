import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/receipt_model.dart';

final receiptsProvider =
    StateNotifierProvider<ReceiptsNotifier, AsyncValue<ReceiptModel?>>((ref) {
  return ReceiptsNotifier(ref.read(apiClientProvider));
});

final receiptListProvider =
    StateNotifierProvider<ReceiptListNotifier, AsyncValue<List<ReceiptModel>>>(
        (ref) {
  return ReceiptListNotifier(ref.read(apiClientProvider));
});

class ReceiptsNotifier extends StateNotifier<AsyncValue<ReceiptModel?>> {
  final ApiClient _apiClient;

  ReceiptsNotifier(this._apiClient) : super(const AsyncValue.data(null));

  Future<ReceiptModel?> uploadAndProcessReceipt(
    Uint8List imageBytes,
    String filename,
  ) async {
    state = const AsyncValue.loading();
    try {
      // 1. Get presigned URL
      final presignedResponse = await _apiClient.get(
        ApiConstants.presignedUrl,
        queryParameters: {
          'filename': filename,
          'contentType': 'image/jpeg',
        },
      );

      final data = presignedResponse['data'] as Map<String, dynamic>;
      final uploadUrl = data['uploadUrl'] as String;
      final s3Key = data['s3Key'] as String;

      // 2. Upload to S3
      await _apiClient.uploadFile(uploadUrl, imageBytes, 'image/jpeg');

      // 3. Process receipt via LLM
      final processResponse = await _apiClient.post(
        ApiConstants.processReceipt,
        data: {'s3Key': s3Key},
      );

      if (processResponse['success'] == true) {
        final receipt = ReceiptModel.fromJson(
          processResponse['data'] as Map<String, dynamic>,
        );
        state = AsyncValue.data(receipt);
        return receipt;
      }
      state = const AsyncValue.data(null);
      return null;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

class ReceiptListNotifier
    extends StateNotifier<AsyncValue<List<ReceiptModel>>> {
  final ApiClient _apiClient;

  ReceiptListNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    loadReceipts();
  }

  Future<void> loadReceipts() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiClient.get(ApiConstants.receipts);
      // Receipt list returns simplified receipts without line items
      final list = (response['data'] as List).map((e) {
        final map = e as Map<String, dynamic>;
        return ReceiptModel(
          id: map['id'] as String,
          merchantName: map['merchantName'] as String? ??
              map['merchant_name'] as String?,
          transactionDate: map['transactionDate'] as String? ??
              map['transaction_date'] as String?,
          total: double.tryParse(map['total']?.toString() ?? ''),
          confidenceScore: double.tryParse(
              map['confidenceScore']?.toString() ??
                  map['confidence_score']?.toString() ??
                  ''),
        );
      }).toList();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteReceipt(String id) async {
    await _apiClient.delete('${ApiConstants.receipts}/$id');
    await loadReceipts();
  }
}
