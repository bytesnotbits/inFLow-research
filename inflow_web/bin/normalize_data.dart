import 'dart:convert';
import 'dart:io';

import 'package:inflow_web/models/product.dart';
import 'package:inflow_web/models/purchase_order_line.dart';
import 'package:inflow_web/models/reorder_setting.dart';
import 'package:inflow_web/models/sales_order_line.dart';
import 'package:inflow_web/models/stock_level.dart';
import 'package:inflow_web/services/data_transform_service.dart';
import 'package:inflow_web/services/model_mapper_service.dart';
import 'package:inflow_web/utils/csv_utils.dart';

Future<void> main(List<String> args) async {
  final builder = NormalizedDatabaseBuilder(
    sourceDir: _resolveProjectDirectory('inflow_web/db/original_exports'),
    outputDir: _resolveProjectDirectory('inflow_web/db/normalized'),
  );
  await builder.build();
}

Directory _resolveProjectDirectory(String relativePath) {
  final current = Directory.current;
  final direct = Directory('${current.path}/$relativePath');
  if (direct.existsSync()) {
    return direct;
  }
  final parent = Directory('${current.parent.path}/$relativePath');
  if (parent.existsSync()) {
    return parent;
  }
  throw FileSystemException(
    'Unable to find $relativePath from ${current.path}',
    relativePath,
  );
}

typedef _Mapper<T> = T? Function(Map<String, String> row);

class NormalizedDatabaseBuilder {
  NormalizedDatabaseBuilder({
    required this.sourceDir,
    required Directory outputDir,
  }) : outputDir = outputDir..createSync(recursive: true);

  final Directory sourceDir;
  final Directory outputDir;

  Future<void> build() async {
    if (!sourceDir.existsSync()) {
      throw FileSystemException(
        'Source directory not found: ${sourceDir.path}',
        sourceDir.path,
      );
    }

    stdout.writeln('Scanning CSV exports in ${sourceDir.path}');
    final summaries = <Map<String, dynamic>>[];
    final counts = <String, int>{};

    final products = await _loadSingleFile<Product>(
      fileName: 'inFlow_ProductDetails.csv',
      datasetName: 'products',
      mapper: ModelMapperService.mapToProduct,
      summaries: summaries,
      counts: counts,
    );

    final salesOrderLines = await _loadSingleFile<SalesOrderLine>(
      fileName: 'inFlow_SalesOrder.csv',
      datasetName: 'salesOrderLines',
      mapper: ModelMapperService.mapToSalesOrderLine,
      summaries: summaries,
      counts: counts,
    );

    final purchaseOrderLines = await _loadSingleFile<PurchaseOrderLine>(
      fileName: 'inFlow_PurchaseOrder.csv',
      datasetName: 'purchaseOrderLines',
      mapper: ModelMapperService.mapToPurchaseOrderLine,
      summaries: summaries,
      counts: counts,
    );

    final stockLevels = await _loadSingleFile<StockLevel>(
      fileName: 'inFlow_StockLevels.csv',
      datasetName: 'stockLevels',
      mapper: ModelMapperService.mapToStockLevel,
      summaries: summaries,
      counts: counts,
    );

    final reorderSettings = await _loadSingleFile<ReorderSetting>(
      fileName: 'inFlow_ReorderSettings.csv',
      datasetName: 'reorderSettings',
      mapper: ModelMapperService.mapToReorderSetting,
      summaries: summaries,
      counts: counts,
    );

    final inventoryTransactions = await _loadTransactionHistory(
      summaries: summaries,
      counts: counts,
    );

    final payload = <String, dynamic>{
      'generatedAt': DateTime.now().toIso8601String(),
      'sourceDirectory': sourceDir.path,
      'counts': counts,
      'filesProcessed': summaries,
      'products': products,
      'salesOrderLines': salesOrderLines,
      'purchaseOrderLines': purchaseOrderLines,
      'stockLevels': stockLevels,
      'reorderSettings': reorderSettings,
      'inventoryTransactions': inventoryTransactions,
    };

    final outputFile = File('${outputDir.path}/normalized_database.json');
    final encoder = const JsonEncoder.withIndent('  ');
    await outputFile.writeAsString(encoder.convert(payload));
    stdout
        .writeln('Normalized database generated at ${outputFile.path}\nCounts: $counts');
  }

  Future<List<Map<String, dynamic>>> _loadSingleFile<T>({
    required String fileName,
    required String datasetName,
    required _Mapper<T> mapper,
    required List<Map<String, dynamic>> summaries,
    required Map<String, int> counts,
  }) async {
    final file = File('${sourceDir.path}/$fileName');
    if (!file.existsSync()) {
      stdout.writeln('⚠️  Skipping $datasetName (missing $fileName)');
      counts[datasetName] = 0;
      return [];
    }
    final result = await _processFile(file, mapper);
    summaries.add(result.summary(datasetName, sourceDir.path));
    counts[datasetName] = result.mappedCount;
    stdout.writeln(
      '• $datasetName: ${result.mappedCount} of ${result.rowCount} rows mapped from $fileName',
    );
    return result.records;
  }

  Future<List<Map<String, dynamic>>> _loadTransactionHistory({
    required List<Map<String, dynamic>> summaries,
    required Map<String, int> counts,
  }) async {
    final files = sourceDir
        .listSync()
        .whereType<File>()
        .where(
          (file) => file.path.toLowerCase().contains('inv_product_transactionhistory'),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      stdout.writeln('⚠️  No transaction history files found.');
      counts['inventoryTransactions'] = 0;
      return [];
    }

    final allRecords = <Map<String, dynamic>>[];
    var totalRows = 0;
    for (final file in files) {
      final result = await _processFile(file, ModelMapperService.mapToInventoryTransaction);
      summaries.add(result.summary('inventoryTransactions', sourceDir.path));
      totalRows += result.rowCount;
      allRecords.addAll(result.records);
      stdout.writeln(
        '• inventoryTransactions (+${result.mappedCount} from ${_relativePath(file.path, sourceDir.path)})',
      );
    }
    counts['inventoryTransactions'] = allRecords.length;
    stdout
        .writeln('Total inventory transactions: ${allRecords.length} (source rows: $totalRows)');
    return allRecords;
  }

  Future<_FileProcessingResult> _processFile<T>(
    File file,
    _Mapper<T> mapper,
  ) async {
    final content = await file.readAsString();
    final parsedRows = CsvUtils.parseContent(content);
    if (parsedRows.isEmpty) {
      return _FileProcessingResult.empty(file.path);
    }
    final headers = parsedRows.first.keys.toList();
    final dateColumns = _detectDateColumns(headers);
    final transformed =
        DataTransformService.transformRows(parsedRows, dateColumns: dateColumns);
    final records = <Map<String, dynamic>>[];
    for (var i = 0; i < transformed.length; i++) {
      final mapped = mapper(transformed[i]);
      if (mapped == null) continue;
      records.add(_wrapRecord(file.path, i + 2, mapped));
    }
    return _FileProcessingResult(
      filePath: file.path,
      rowCount: transformed.length,
      mappedCount: records.length,
      records: records,
    );
  }

  List<String> _detectDateColumns(List<String> headers) {
    return headers
        .where(
          (header) => header.toLowerCase().contains('date'),
        )
        .toList();
  }

  Map<String, dynamic> _wrapRecord(
    String filePath,
    int sourceRow,
    dynamic record,
  ) {
    return {
      'sourceFile': _relativePath(filePath, sourceDir.path),
      'sourceRow': sourceRow,
      'record': record.toJson(),
    };
  }

  String _relativePath(String fullPath, String rootPath) {
    final normalizedFull = fullPath.replaceAll('\\', '/');
    final normalizedRoot = rootPath.replaceAll('\\', '/');
    if (normalizedFull.startsWith('$normalizedRoot/')) {
      return normalizedFull.substring(normalizedRoot.length + 1);
    }
    return normalizedFull;
  }
}

class _FileProcessingResult {
  const _FileProcessingResult({
    required this.filePath,
    required this.rowCount,
    required this.mappedCount,
    required this.records,
  });

  factory _FileProcessingResult.empty(String path) => _FileProcessingResult(
        filePath: path,
        rowCount: 0,
        mappedCount: 0,
        records: const [],
      );

  final String filePath;
  final int rowCount;
  final int mappedCount;
  final List<Map<String, dynamic>> records;

  Map<String, dynamic> summary(String dataset, String rootPath) => {
        'dataset': dataset,
        'file': _relativePath(filePath, rootPath),
        'rowCount': rowCount,
        'mappedCount': mappedCount,
      };

  String _relativePath(String fullPath, String rootPath) {
    final normalizedFull = fullPath.replaceAll('\\', '/');
    final normalizedRoot = rootPath.replaceAll('\\', '/');
    if (normalizedFull.startsWith('$normalizedRoot/')) {
      return normalizedFull.substring(normalizedRoot.length + 1);
    }
    return normalizedFull;
  }
}
