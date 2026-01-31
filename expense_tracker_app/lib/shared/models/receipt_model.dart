class ReceiptModel {
  final String id;
  final String? merchantName;
  final String? transactionDate;
  final double? total;
  final double? confidenceScore;
  final String? imageUrl;
  final List<LineItemModel> lineItems;

  const ReceiptModel({
    required this.id,
    this.merchantName,
    this.transactionDate,
    this.total,
    this.confidenceScore,
    this.imageUrl,
    this.lineItems = const [],
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    final receipt = json['receipt'] as Map<String, dynamic>? ?? json;
    final items = json['lineItems'] as List<dynamic>? ??
        json['line_items'] as List<dynamic>? ??
        [];

    return ReceiptModel(
      id: receipt['id'] as String? ?? '',
      merchantName: receipt['merchantName'] as String? ??
          receipt['merchant_name'] as String?,
      transactionDate: receipt['transactionDate'] as String? ??
          receipt['transaction_date'] as String?,
      total: double.tryParse(receipt['total']?.toString() ?? ''),
      confidenceScore: double.tryParse(
          receipt['confidenceScore']?.toString() ??
              receipt['confidence_score']?.toString() ??
              ''),
      imageUrl: receipt['imageUrl'] as String? ?? receipt['image_url'] as String?,
      lineItems:
          items.map((e) => LineItemModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class LineItemModel {
  final String description;
  final double quantity;
  final double unitPrice;
  final double totalPrice;
  final String? categorySuggestion;
  String? selectedCategoryId;
  bool isSelected;

  LineItemModel({
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    required this.totalPrice,
    this.categorySuggestion,
    this.selectedCategoryId,
    this.isSelected = true,
  });

  factory LineItemModel.fromJson(Map<String, dynamic> json) {
    return LineItemModel(
      description: json['description'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ??
          (json['unitPrice'] as num?)?.toDouble() ??
          0,
      totalPrice: (json['total_price'] as num?)?.toDouble() ??
          (json['totalPrice'] as num?)?.toDouble() ??
          0,
      categorySuggestion: json['category_suggestion'] as String? ??
          json['categorySuggestion'] as String?,
    );
  }
}
