import 'inventory_transaction.dart';
import 'product.dart';
import 'purchase_order_line.dart';
import 'reorder_setting.dart';
import 'sales_order_line.dart';
import 'stock_level.dart';

class NormalizedDatabase {
  final DateTime generatedAt;
  final String sourceDirectory;
  final Map<String, int> counts;
  final List<NormalizedFileSummary> filesProcessed;
  final List<NormalizedRecord<Product>> products;
  final List<NormalizedRecord<SalesOrderLine>> salesOrderLines;
  final List<NormalizedRecord<PurchaseOrderLine>> purchaseOrderLines;
  final List<NormalizedRecord<InventoryTransaction>> inventoryTransactions;
  final List<NormalizedRecord<StockLevel>> stockLevels;
  final List<NormalizedRecord<ReorderSetting>> reorderSettings;

  const NormalizedDatabase({
    required this.generatedAt,
    required this.sourceDirectory,
    required this.counts,
    required this.filesProcessed,
    required this.products,
    required this.salesOrderLines,
    required this.purchaseOrderLines,
    required this.inventoryTransactions,
    required this.stockLevels,
    required this.reorderSettings,
  });

  factory NormalizedDatabase.fromJson(Map<String, dynamic> json) {
    return NormalizedDatabase(
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
          DateTime(1970),
      sourceDirectory: json['sourceDirectory'] as String? ?? '',
      counts: _parseCounts(json['counts']),
      filesProcessed: _parseFileSummaries(json['filesProcessed']),
      products: _parseRecords<Product>(
        json['products'],
        Product.fromJson,
      ),
      salesOrderLines: _parseRecords<SalesOrderLine>(
        json['salesOrderLines'],
        SalesOrderLine.fromJson,
      ),
      purchaseOrderLines: _parseRecords<PurchaseOrderLine>(
        json['purchaseOrderLines'],
        PurchaseOrderLine.fromJson,
      ),
      inventoryTransactions: _parseRecords<InventoryTransaction>(
        json['inventoryTransactions'],
        InventoryTransaction.fromJson,
      ),
      stockLevels: _parseRecords<StockLevel>(
        json['stockLevels'],
        StockLevel.fromJson,
      ),
      reorderSettings: _parseRecords<ReorderSetting>(
        json['reorderSettings'],
        ReorderSetting.fromJson,
      ),
    );
  }

  static Map<String, int> _parseCounts(dynamic value) {
    if (value is! Map) return {};
    final result = <String, int>{};
    value.forEach((key, dynamic raw) {
      final intValue =
          raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? 0;
      result[key.toString()] = intValue;
    });
    return result;
  }

  static List<NormalizedFileSummary> _parseFileSummaries(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(NormalizedFileSummary.fromJson)
        .toList();
  }

  static List<NormalizedRecord<T>> _parseRecords<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (value is! List) return const [];
    final records = <NormalizedRecord<T>>[];
    for (final entry in value) {
      if (entry is! Map) continue;
      final sourceFile = entry['sourceFile']?.toString() ?? '';
      final sourceRow = entry['sourceRow'] is num
          ? (entry['sourceRow'] as num).toInt()
          : int.tryParse(entry['sourceRow']?.toString() ?? '') ?? 0;
      final recordPayload = entry['record'];
      if (recordPayload is! Map) continue;
      final record = parser(Map<String, dynamic>.from(recordPayload));
      records.add(
        NormalizedRecord<T>(
          sourceFile: sourceFile,
          sourceRow: sourceRow,
          record: record,
        ),
      );
    }
    return records;
  }
}

class NormalizedRecord<T> {
  final String sourceFile;
  final int sourceRow;
  final T record;

  const NormalizedRecord({
    required this.sourceFile,
    required this.sourceRow,
    required this.record,
  });
}

class NormalizedFileSummary {
  final String dataset;
  final String file;
  final int rowCount;
  final int mappedCount;

  const NormalizedFileSummary({
    required this.dataset,
    required this.file,
    required this.rowCount,
    required this.mappedCount,
  });

  factory NormalizedFileSummary.fromJson(Map<String, dynamic> json) {
    return NormalizedFileSummary(
      dataset: json['dataset'] as String? ?? '',
      file: json['file'] as String? ?? '',
      rowCount: (json['rowCount'] is num)
          ? (json['rowCount'] as num).toInt()
          : int.tryParse(json['rowCount']?.toString() ?? '') ?? 0,
      mappedCount: (json['mappedCount'] is num)
          ? (json['mappedCount'] as num).toInt()
          : int.tryParse(json['mappedCount']?.toString() ?? '') ?? 0,
    );
  }
}
