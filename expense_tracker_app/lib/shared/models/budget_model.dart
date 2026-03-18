class BudgetModel {
  final String id;
  final String? userId;
  final String? groupId;
  final String name;
  final String month;
  final String currency;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BudgetModel({
    required this.id,
    this.userId,
    this.groupId,
    required this.name,
    required this.month,
    this.currency = 'PHP',
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isGroupBudget => groupId != null;

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      groupId: json['groupId'] as String? ?? json['group_id'] as String?,
      name: json['name'] as String,
      month: json['month'] as String,
      currency: json['currency'] as String? ?? 'PHP',
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : json['updated_at'] != null
              ? DateTime.tryParse(json['updated_at'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'month': month,
        'currency': currency,
        if (groupId != null) 'groupId': groupId,
        if (notes != null) 'notes': notes,
      };
}
