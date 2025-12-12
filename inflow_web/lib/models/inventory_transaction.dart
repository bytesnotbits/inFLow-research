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

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryTransaction(
      transactionType: json['transactionType'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(1970),
      location: json['location'] as String? ?? '',
      sublocation: json['sublocation'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      qtyBefore: (json['qtyBefore'] as num?)?.toDouble() ?? 0,
      qtyAfter: (json['qtyAfter'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'transactionType': transactionType,
        'date': date.toIso8601String(),
        'location': location,
        'sublocation': sublocation,
        'orderNumber': orderNumber,
        'quantity': quantity,
        'qtyBefore': qtyBefore,
        'qtyAfter': qtyAfter,
      };
}
