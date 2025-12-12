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

  factory ReorderSetting.fromJson(Map<String, dynamic> json) {
    return ReorderSetting(
      productName: json['productName'] as String? ?? '',
      location: json['location'] as String? ?? '',
      defaultSublocation: json['defaultSublocation'] as String? ?? '',
      enableReordering: json['enableReordering'] as bool? ?? false,
      reorderPoint: (json['reorderPoint'] as num?)?.toDouble() ?? 0,
      reorderQuantity: (json['reorderQuantity'] as num?)?.toDouble() ?? 0,
      reorderMethod: json['reorderMethod'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      fromLocation: json['fromLocation'] as String? ?? '',
    );
  }

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
