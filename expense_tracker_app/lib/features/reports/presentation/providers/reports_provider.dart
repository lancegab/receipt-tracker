import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/transaction_model.dart';

class ReportsState {
  final List<TransactionModel> transactions;
  final double totalIncome;
  final double totalExpense;
  final Map<String, double> categoryBreakdown;
  final bool isLoading;

  const ReportsState({
    this.transactions = const [],
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.categoryBreakdown = const {},
    this.isLoading = false,
  });

  double get net => totalIncome - totalExpense;
}

final reportsProvider =
    StateNotifierProvider<ReportsNotifier, ReportsState>((ref) {
  return ReportsNotifier(ref.read(apiClientProvider));
});

class ReportsNotifier extends StateNotifier<ReportsState> {
  final ApiClient _apiClient;

  ReportsNotifier(this._apiClient) : super(const ReportsState()) {
    final now = DateTime.now();
    loadReport(now.year, now.month);
  }

  Future<void> loadReport(int year, int month) async {
    state = const ReportsState(isLoading: true);
    try {
      final startDate =
          '$year-${month.toString().padLeft(2, '0')}-01';
      final lastDay = DateTime(year, month + 1, 0).day;
      final endDate =
          '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

      final response = await _apiClient.get(
        ApiConstants.transactions,
        queryParameters: {
          'startDate': startDate,
          'endDate': endDate,
          'limit': '500',
        },
      );

      final txns = (response['data'] as List)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      double income = 0;
      double expense = 0;
      final catMap = <String, double>{};

      for (final txn in txns) {
        if (txn.type == 'income') {
          income += txn.amount;
        } else if (txn.type == 'expense') {
          expense += txn.amount;
          final cat = txn.categoryId ?? 'Uncategorized';
          catMap[cat] = (catMap[cat] ?? 0) + txn.amount;
        }
      }

      state = ReportsState(
        transactions: txns,
        totalIncome: income,
        totalExpense: expense,
        categoryBreakdown: catMap,
      );
    } catch (_) {
      state = const ReportsState();
    }
  }
}
