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

  factory StockLevel.fromJson(Map<String, dynamic> json) {
    return StockLevel(
      productName: json['productName'] as String? ?? '',
      location: json['location'] as String? ?? '',
      sublocation: json['sublocation'] as String? ?? '',
      serial: json['serial'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'location': location,
        'sublocation': sublocation,
        'serial': serial,
        'quantity': quantity,
      };
}
