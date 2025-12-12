class PurchaseOrderLine {
  final String orderNumber;
  final String vendor;
  final DateTime orderDate;
  final String productSku;
  final String productName;
  final String productDescription;
  final double quantity;
  final double unitPrice;
  final String location;
  // Add other fields as needed

  PurchaseOrderLine({
    required this.orderNumber,
    required this.vendor,
    required this.orderDate,
    required this.productSku,
    required this.productName,
    required this.productDescription,
    required this.quantity,
    required this.unitPrice,
    required this.location,
  });

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderLine(
      orderNumber: json['orderNumber'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      orderDate: DateTime.tryParse(json['orderDate'] as String? ?? '') ??
          DateTime(1970),
      productSku: json['productSku'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      productDescription: json['productDescription'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      location: json['location'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'orderNumber': orderNumber,
        'vendor': vendor,
        'orderDate': orderDate.toIso8601String(),
        'productSku': productSku,
        'productName': productName,
        'productDescription': productDescription,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'location': location,
      };
}
