class AccountModel {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String currency;
  final double balance;
  final double? creditLimit;
  final int? statementCloseDay;
  final int? paymentDueDay;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AccountModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.currency = 'USD',
    this.balance = 0,
    this.creditLimit,
    this.statementCloseDay,
    this.paymentDueDay,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isCreditCard => type == 'credit_card';

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      name: json['name'] as String,
      type: json['type'] as String,
      currency: json['currency'] as String? ?? 'USD',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0,
      creditLimit: json['creditLimit'] != null || json['credit_limit'] != null
          ? double.tryParse(
              (json['creditLimit'] ?? json['credit_limit']).toString())
          : null,
      statementCloseDay: json['statementCloseDay'] as int? ??
          json['statement_close_day'] as int?,
      paymentDueDay:
          json['paymentDueDay'] as int? ?? json['payment_due_day'] as int?,
      isArchived: json['isArchived'] as bool? ??
          json['is_archived'] as bool? ??
          false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'currency': currency,
        'balance': balance,
        if (creditLimit != null) 'creditLimit': creditLimit,
        if (statementCloseDay != null) 'statementCloseDay': statementCloseDay,
        if (paymentDueDay != null) 'paymentDueDay': paymentDueDay,
      };
}
