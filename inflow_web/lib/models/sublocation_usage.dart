enum SublocationUsageType { shelf, reel, unknown }

class SublocationUsage {
  final String sublocation;
  final SublocationUsageType usageType;
  final String relatedProductSku;
  final String notes;

  SublocationUsage({
    required this.sublocation,
    required this.usageType,
    required this.relatedProductSku,
    required this.notes,
  });
}
