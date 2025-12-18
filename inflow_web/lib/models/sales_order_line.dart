class SalesOrderLine {
  final String orderNumber;
  final String customer;
  final String contact;
  final DateTime orderDate;
  final String productSku;
  final String productName;
  final String productDescription;
  final double quantity;
  final double unitPrice;
  final String location;
  // Add other fields as needed

  SalesOrderLine({
    required this.orderNumber,
    required this.customer,
    required this.contact,
    required this.orderDate,
    required this.productSku,
    required this.productName,
    required this.productDescription,
    required this.quantity,
    required this.unitPrice,
    required this.location,
  });

  factory SalesOrderLine.fromJson(Map<String, dynamic> json) {
    return SalesOrderLine(
      orderNumber: json['orderNumber'] as String? ?? '',
      customer: json['customer'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      orderDate: DateTime.tryParse(json['orderDate'] as String? ?? '') ??
          DateTime(1970),
      productSku: json['productSku'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      productDescription: json['productDescription'] as String? ??
          json['description'] as String? ??
          '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      location: json['location'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'orderNumber': orderNumber,
        'customer': customer,
        'contact': contact,
        'orderDate': orderDate.toIso8601String(),
        'productSku': productSku,
        'productName': productName,
        'productDescription': productDescription,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'location': location,
      };
}
