class InstallmentModel {
  final String id;
  final String userId;
  final String accountId;
  final String description;
  final double totalAmount;
  final double monthlyAmount;
  final int totalMonths;
  final String startMonth;
  final String endMonth;
  final String? categoryId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InstallmentModel({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.description,
    required this.totalAmount,
    required this.monthlyAmount,
    required this.totalMonths,
    required this.startMonth,
    required this.endMonth,
    this.categoryId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// How many months have elapsed since startMonth
  int get monthsElapsed {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final startParts = startMonth.split('-').map(int.parse).toList();
    final currentParts = currentMonth.split('-').map(int.parse).toList();
    final diff =
        (currentParts[0] * 12 + currentParts[1]) -
        (startParts[0] * 12 + startParts[1]);
    return diff.clamp(0, totalMonths);
  }

  int get monthsRemaining => totalMonths - monthsElapsed;

  double get progressPercent =>
      totalMonths > 0 ? monthsElapsed / totalMonths : 0;

  factory InstallmentModel.fromJson(Map<String, dynamic> json) {
    return InstallmentModel(
      id: json['id'] as String,
      userId:
          json['userId'] as String? ?? json['user_id'] as String? ?? '',
      accountId: json['accountId'] as String? ??
          json['account_id'] as String? ??
          '',
      description: json['description'] as String,
      totalAmount: double.tryParse(
              json['totalAmount']?.toString() ??
                  json['total_amount']?.toString() ??
                  '0') ??
          0,
      monthlyAmount: double.tryParse(
              json['monthlyAmount']?.toString() ??
                  json['monthly_amount']?.toString() ??
                  '0') ??
          0,
      totalMonths: json['totalMonths'] as int? ??
          json['total_months'] as int? ??
          0,
      startMonth: json['startMonth'] as String? ??
          json['start_month'] as String? ??
          '',
      endMonth: json['endMonth'] as String? ??
          json['end_month'] as String? ??
          '',
      categoryId: json['categoryId'] as String? ??
          json['category_id'] as String?,
      isActive: json['isActive'] as bool? ??
          json['is_active'] as bool? ??
          true,
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
        'accountId': accountId,
        'description': description,
        'totalAmount': totalAmount,
        'totalMonths': totalMonths,
        'startMonth': startMonth,
        if (categoryId != null) 'categoryId': categoryId,
      };
}
