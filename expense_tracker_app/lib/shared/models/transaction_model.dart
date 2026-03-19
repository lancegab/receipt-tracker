class TransactionModel {
  final String id;
  final String userId;
  final String accountId;
  final String type;
  final double amount;
  final String date;
  final String? time;
  final String description;
  final String? merchantName;
  final String? categoryId;
  final String? notes;
  final String? receiptId;
  final String? transferToAccountId;
  final String? budgetItemId;
  final bool isPending;
  final DateTime? createdAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.date,
    this.time,
    required this.description,
    this.merchantName,
    this.categoryId,
    this.notes,
    this.receiptId,
    this.transferToAccountId,
    this.budgetItemId,
    this.isPending = false,
    this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      accountId:
          json['accountId'] as String? ?? json['account_id'] as String? ?? '',
      type: json['type'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      date: json['date'] as String,
      time: json['time'] as String?,
      description: json['description'] as String,
      merchantName:
          json['merchantName'] as String? ?? json['merchant_name'] as String?,
      categoryId:
          json['categoryId'] as String? ?? json['category_id'] as String?,
      notes: json['notes'] as String?,
      receiptId:
          json['receiptId'] as String? ?? json['receipt_id'] as String?,
      transferToAccountId: json['transferToAccountId'] as String? ??
          json['transfer_to_account_id'] as String?,
      budgetItemId: json['budgetItemId'] as String? ??
          json['budget_item_id'] as String?,
      isPending: json['isPending'] as bool? ??
          json['is_pending'] as bool? ??
          false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'type': type,
        'amount': amount,
        'date': date,
        if (time != null) 'time': time,
        'description': description,
        if (merchantName != null) 'merchantName': merchantName,
        if (categoryId != null) 'categoryId': categoryId,
        if (notes != null) 'notes': notes,
        if (receiptId != null) 'receiptId': receiptId,
        if (transferToAccountId != null)
          'transferToAccountId': transferToAccountId,
        if (budgetItemId != null) 'budgetItemId': budgetItemId,
        'isPending': isPending,
      };
}
