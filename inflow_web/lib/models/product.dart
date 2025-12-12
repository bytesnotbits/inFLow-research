class Product {
  final String sku;
  final String name;
  final String description;
  final String category;
  final bool isActive;
  final double defaultUnitPrice;
  final String vendor;
  final String uom;
  // Add other fields as needed

  Product({
    required this.sku,
    required this.name,
    required this.description,
    required this.category,
    required this.isActive,
    required this.defaultUnitPrice,
    required this.vendor,
    required this.uom,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      sku: json['sku'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      defaultUnitPrice: (json['defaultUnitPrice'] as num?)?.toDouble() ?? 0,
      vendor: json['vendor'] as String? ?? '',
      uom: json['uom'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'name': name,
        'description': description,
        'category': category,
        'isActive': isActive,
        'defaultUnitPrice': defaultUnitPrice,
        'vendor': vendor,
        'uom': uom,
      };
}
