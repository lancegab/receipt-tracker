class RecurringTransactionModel {
  final String id;
  final String userId;
  final String accountId;
  final String type;
  final double amount;
  final String description;
  final String? categoryId;
  final String frequency;
  final String startDate;
  final String? endDate;
  final String nextOccurrence;
  final bool isActive;

  const RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.description,
    this.categoryId,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.nextOccurrence,
    this.isActive = true,
  });

  factory RecurringTransactionModel.fromJson(Map<String, dynamic> json) {
    return RecurringTransactionModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      accountId:
          json['accountId'] as String? ?? json['account_id'] as String? ?? '',
      type: json['type'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      description: json['description'] as String,
      categoryId:
          json['categoryId'] as String? ?? json['category_id'] as String?,
      frequency: json['frequency'] as String,
      startDate:
          json['startDate'] as String? ?? json['start_date'] as String? ?? '',
      endDate: json['endDate'] as String? ?? json['end_date'] as String?,
      nextOccurrence: json['nextOccurrence'] as String? ??
          json['next_occurrence'] as String? ??
          '',
      isActive: json['isActive'] as bool? ??
          json['is_active'] as bool? ??
          true,
    );
  }

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'type': type,
        'amount': amount,
        'description': description,
        if (categoryId != null) 'categoryId': categoryId,
        'frequency': frequency,
        'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };

  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Bi-weekly';
      case 'monthly':
        return 'Monthly';
      case 'quarterly':
        return 'Quarterly';
      case 'yearly':
        return 'Yearly';
      default:
        return frequency;
    }
  }
}
