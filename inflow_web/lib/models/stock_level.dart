class StockLevel {
  final String productName;
  final String location;
  final String sublocation;
  final String serial;
  final double quantity;

  const StockLevel({
    required this.productName,
    required this.location,
    required this.sublocation,
    required this.serial,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'location': location,
        'sublocation': sublocation,
        'serial': serial,
        'quantity': quantity,
      };
}
