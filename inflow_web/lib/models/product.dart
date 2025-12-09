class Product {
  final String sku;
  final String name;
  final String category;
  final bool isActive;
  final double defaultUnitPrice;
  final String vendor;
  final String uom;
  // Add other fields as needed

  Product({
    required this.sku,
    required this.name,
    required this.category,
    required this.isActive,
    required this.defaultUnitPrice,
    required this.vendor,
    required this.uom,
  });
}
