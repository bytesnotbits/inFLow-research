class InventoryTransaction {
  final String transactionType;
  final DateTime date;
  final String location;
  final String sublocation; // Dual-purpose: shelf or reel
  final String orderNumber;
  final double quantity;
  final double qtyBefore;
  final double qtyAfter;

  InventoryTransaction({
    required this.transactionType,
    required this.date,
    required this.location,
    required this.sublocation,
    required this.orderNumber,
    required this.quantity,
    required this.qtyBefore,
    required this.qtyAfter,
  });
}
