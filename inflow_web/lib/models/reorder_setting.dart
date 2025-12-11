class ReorderSetting {
  final String productName;
  final String location;
  final String defaultSublocation;
  final bool enableReordering;
  final double reorderPoint;
  final double reorderQuantity;
  final String reorderMethod;
  final String vendor;
  final String fromLocation;

  const ReorderSetting({
    required this.productName,
    required this.location,
    required this.defaultSublocation,
    required this.enableReordering,
    required this.reorderPoint,
    required this.reorderQuantity,
    required this.reorderMethod,
    required this.vendor,
    required this.fromLocation,
  });

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'location': location,
        'defaultSublocation': defaultSublocation,
        'enableReordering': enableReordering,
        'reorderPoint': reorderPoint,
        'reorderQuantity': reorderQuantity,
        'reorderMethod': reorderMethod,
        'vendor': vendor,
        'fromLocation': fromLocation,
      };
}
