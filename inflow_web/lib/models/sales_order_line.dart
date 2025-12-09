class SalesOrderLine {
  final String orderNumber;
  final String customer;
  final DateTime orderDate;
  final String productSku;
  final String productName;
  final double quantity;
  final double unitPrice;
  final String location;
  // Add other fields as needed

  SalesOrderLine({
    required this.orderNumber,
    required this.customer,
    required this.orderDate,
    required this.productSku,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.location,
  });
}
