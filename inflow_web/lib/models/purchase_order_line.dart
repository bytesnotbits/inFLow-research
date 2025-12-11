class PurchaseOrderLine {
  final String orderNumber;
  final String vendor;
  final DateTime orderDate;
  final String productSku;
  final String productName;
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
    required this.quantity,
    required this.unitPrice,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
        'orderNumber': orderNumber,
        'vendor': vendor,
        'orderDate': orderDate.toIso8601String(),
        'productSku': productSku,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'location': location,
      };
}
