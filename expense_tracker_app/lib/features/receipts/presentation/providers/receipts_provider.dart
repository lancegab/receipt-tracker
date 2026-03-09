import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
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
      // 1. Save image locally on device
      final appDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory('${appDir.path}/receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final localPath = '${receiptsDir.path}/$filename';
      final file = File(localPath);
      await file.writeAsBytes(imageBytes);

      // 2. Encode image to base64 and send to backend for processing
      final base64Image = base64Encode(imageBytes);
      final processResponse = await _apiClient.post(
        ApiConstants.processReceipt,
        data: {
          'imageBase64': base64Image,
          'contentType': 'image/jpeg',
        },
      );

      if (processResponse['success'] == true) {
        final receiptData =
            processResponse['data'] as Map<String, dynamic>;
        // Inject local image path into receipt data
        if (receiptData['receipt'] is Map<String, dynamic>) {
          (receiptData['receipt'] as Map<String, dynamic>)['imageUrl'] =
              localPath;
        }
        final receipt = ReceiptModel.fromJson(receiptData);
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
