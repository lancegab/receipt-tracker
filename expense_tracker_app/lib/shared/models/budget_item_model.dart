class WeeklyBreakdown {
  final double autoSpent;
  final double manualAdjustment;

  const WeeklyBreakdown({
    this.autoSpent = 0,
    this.manualAdjustment = 0,
  });

  double get total => autoSpent + manualAdjustment;

  factory WeeklyBreakdown.fromJson(Map<String, dynamic> json) {
    return WeeklyBreakdown(
      autoSpent:
          double.tryParse(json['autoSpent']?.toString() ?? '0') ?? 0,
      manualAdjustment:
          double.tryParse(json['manualAdjustment']?.toString() ?? '0') ?? 0,
    );
  }
}

class BudgetItemModel {
  final String id;
  final String budgetId;
  final String name;
  final double budgetedAmount;
  final String? linkedAccountId;
  final String? linkedCategoryId;
  final double manualSpent;
  final double autoSpent;
  final double installmentAmount;
  final double totalSpent;
  final double remaining;
  final int sortOrder;
  final Map<int, WeeklyBreakdown>? weeklyBreakdown;

  const BudgetItemModel({
    required this.id,
    required this.budgetId,
    required this.name,
    this.budgetedAmount = 0,
    this.linkedAccountId,
    this.linkedCategoryId,
    this.manualSpent = 0,
    this.autoSpent = 0,
    this.installmentAmount = 0,
    this.totalSpent = 0,
    this.remaining = 0,
    this.sortOrder = 0,
    this.weeklyBreakdown,
  });

  double get spentPercentage =>
      budgetedAmount > 0 ? (totalSpent / budgetedAmount).clamp(0, 2) : 0;

  bool get isOverBudget => totalSpent > budgetedAmount;
  bool get hasLinkedSource =>
      linkedAccountId != null || linkedCategoryId != null;

  factory BudgetItemModel.fromJson(Map<String, dynamic> json) {
    Map<int, WeeklyBreakdown>? weekly;
    final wb = json['weeklyBreakdown'] ?? json['weekly_breakdown'];
    if (wb is Map) {
      weekly = {};
      for (final entry in wb.entries) {
        final weekNum = int.tryParse(entry.key.toString());
        if (weekNum != null && entry.value is Map) {
          weekly[weekNum] = WeeklyBreakdown.fromJson(
              Map<String, dynamic>.from(entry.value as Map));
        }
      }
    }

    return BudgetItemModel(
      id: json['id'] as String,
      budgetId: json['budgetId'] as String? ??
          json['budget_id'] as String? ??
          '',
      name: json['name'] as String,
      budgetedAmount: double.tryParse(
              json['budgetedAmount']?.toString() ??
                  json['budgeted_amount']?.toString() ??
                  '0') ??
          0,
      linkedAccountId: json['linkedAccountId'] as String? ??
          json['linked_account_id'] as String?,
      linkedCategoryId: json['linkedCategoryId'] as String? ??
          json['linked_category_id'] as String?,
      manualSpent: double.tryParse(
              json['manualSpent']?.toString() ??
                  json['manual_spent']?.toString() ??
                  '0') ??
          0,
      autoSpent: double.tryParse(
              json['autoSpent']?.toString() ??
                  json['auto_spent']?.toString() ??
                  '0') ??
          0,
      installmentAmount: double.tryParse(
              json['installmentAmount']?.toString() ??
                  json['installment_amount']?.toString() ??
                  '0') ??
          0,
      totalSpent: double.tryParse(
              json['totalSpent']?.toString() ??
                  json['total_spent']?.toString() ??
                  '0') ??
          0,
      remaining: double.tryParse(
              json['remaining']?.toString() ?? '0') ??
          0,
      sortOrder: json['sortOrder'] as int? ??
          json['sort_order'] as int? ??
          0,
      weeklyBreakdown: weekly,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'budgetedAmount': budgetedAmount,
        if (linkedAccountId != null) 'linkedAccountId': linkedAccountId,
        if (linkedCategoryId != null) 'linkedCategoryId': linkedCategoryId,
        'sortOrder': sortOrder,
      };
}

class BudgetSummaryModel {
  final Map<String, dynamic> budget;
  final List<BudgetItemModel> items;
  final double totalBudgeted;
  final double totalSpent;
  final double totalRemaining;

  const BudgetSummaryModel({
    required this.budget,
    required this.items,
    this.totalBudgeted = 0,
    this.totalSpent = 0,
    this.totalRemaining = 0,
  });

  factory BudgetSummaryModel.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? {};
    return BudgetSummaryModel(
      budget: json['budget'] as Map<String, dynamic>? ?? {},
      items: (json['items'] as List? ?? [])
          .map((e) => BudgetItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalBudgeted:
          double.tryParse(totals['totalBudgeted']?.toString() ?? '0') ?? 0,
      totalSpent:
          double.tryParse(totals['totalSpent']?.toString() ?? '0') ?? 0,
      totalRemaining:
          double.tryParse(totals['totalRemaining']?.toString() ?? '0') ?? 0,
    );
  }
}
