import 'models/product.dart';
import 'models/sales_order_line.dart';
import 'models/purchase_order_line.dart';
import 'models/inventory_transaction.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/file_import_service.dart';
import 'services/csv_parser_service.dart';
import 'services/data_transform_service.dart';
import 'services/model_mapper_service.dart';
import 'services/column_inspector_service.dart';
import 'services/dataset_analysis_service.dart';
import 'services/csv_export_service.dart';
import 'services/validation_service.dart';
import 'models/imported_dataset.dart';

void main() {
  runApp(const InflowWebApp());
}

class InflowWebApp extends StatelessWidget {
  const InflowWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'inFlow Inventory Research',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // For demo: store mapped objects
  List<Product>? _products;
  List<SalesOrderLine>? _salesOrderLines;
  List<PurchaseOrderLine>? _purchaseOrderLines;
  List<InventoryTransaction>? _inventoryTransactions;
  ColumnStats? _selectedColumnStats;
  DatasetAnalysis? _analysis;
  List<Map<String, String>>? _parsedRows;
  List<Map<String, String>>? _filteredRows;
  List<String>? _headers;
  String? _fileName;
  String _searchQuery = '';
  String? _searchColumn;
  bool _isImporting = false;
  bool _showMetadataPanel = false;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  // Multi-file support
  List<ImportedDataset> _importedDatasets = [];
  ImportedDataset? _activeDataset;

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _importFiles() async {
    setState(() {
      _isImporting = true;
    });
    try {
      final files = await FileImportService.pickFiles();
      if (files.isEmpty) {
        _showErrorDialog(
            'No file selected', 'Please select a CSV file to import.');
        return;
      }

      for (final file in files) {
        // Validate file
        final fileValidation =
            ValidationService.validateFile(file.name, file.size);
        if (!fileValidation.isValid) {
          _showErrorDialog(
              'Invalid File: ${file.name}', fileValidation.message);
          continue;
        }

        // Parse CSV
        var rows = CsvParserService.parseCsv(file);

        // Validate parsed data
        final dataValidation = ValidationService.validateCsvData(
            rows, rows.isNotEmpty ? rows.first.keys.toList() : []);
        if (!dataValidation.isValid) {
          _showErrorDialog(
              'Invalid CSV Data: ${file.name}', dataValidation.message);
          continue;
        }

        // Guess common date columns
        final dateColumns = rows.first.keys
            .where((k) => k.toLowerCase().contains('date'))
            .toList();
        rows =
            DataTransformService.transformRows(rows, dateColumns: dateColumns);

        // Create dataset
        final dataset = ImportedDataset(
          fileName: file.name,
          importedAt: DateTime.now(),
          rows: rows,
          headers: rows.first.keys.toList(),
        );

        setState(() {
          _importedDatasets.add(dataset);
          _activeDataset = dataset;
          _updateActiveDataset(dataset);
        });
      }

      if (_importedDatasets.isNotEmpty) {
        _showSuccessSnackBar(
            '${_importedDatasets.length} file(s) imported successfully!');
      }
    } catch (e) {
      _showErrorDialog('Import Error', 'An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  void _updateActiveDataset(ImportedDataset dataset) {
    // Map to domain models (try all types, filter nulls)
    final products = dataset.rows
        .map(ModelMapperService.mapToProduct)
        .whereType<Product>()
        .toList();
    final salesOrderLines = dataset.rows
        .map(ModelMapperService.mapToSalesOrderLine)
        .whereType<SalesOrderLine>()
        .toList();
    final purchaseOrderLines = dataset.rows
        .map(ModelMapperService.mapToPurchaseOrderLine)
        .whereType<PurchaseOrderLine>()
        .toList();
    final inventoryTransactions = dataset.rows
        .map(ModelMapperService.mapToInventoryTransaction)
        .whereType<InventoryTransaction>()
        .toList();

    // Analyze dataset
    final analysis =
        DatasetAnalysisService.analyzeDataset(dataset.rows, dataset.headers);

    setState(() {
      _parsedRows = dataset.rows;
      _filteredRows = dataset.rows;
      _headers = dataset.headers;
      _fileName = dataset.fileName;
      _searchQuery = '';
      _searchColumn = null;
      _products = products;
      _salesOrderLines = salesOrderLines;
      _purchaseOrderLines = purchaseOrderLines;
      _inventoryTransactions = inventoryTransactions;
      _analysis = analysis;
      _showMetadataPanel = false;
    });
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _filterRows() {
    if (_parsedRows == null || _searchQuery.isEmpty || _searchColumn == null) {
      setState(() {
        _filteredRows = _parsedRows;
        _selectedColumnStats =
            _searchColumn != null && _headers != null && _parsedRows != null
                ? ColumnInspectorService.inspectColumns(
                    _parsedRows!, _headers!)[_searchColumn!]
                : null;
      });
      return;
    }
    setState(() {
      _filteredRows = _parsedRows!.where((row) {
        final value = row[_searchColumn!]?.toLowerCase() ?? '';
        return value.contains(_searchQuery.toLowerCase());
      }).toList();
      _selectedColumnStats =
          _searchColumn != null && _headers != null && _parsedRows != null
              ? ColumnInspectorService.inspectColumns(
                  _parsedRows!, _headers!)[_searchColumn!]
              : null;
    });
  }

  Widget _buildMetadataContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('File: ${_fileName ?? 'Unknown'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (_analysis != null) ...[
          const SizedBox(height: 8),
          Text(
              'Rows: ${_analysis!.rowCount}, Columns: ${_analysis!.columnCount}'),
          if (_analysis!.dateRanges.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Date Ranges:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (final entry in _analysis!.dateRanges.entries)
              Text(
                  '${entry.key}: ${entry.value.range} (${entry.value.count} dates)'),
          ],
        ],
        const SizedBox(height: 12),
        if (_products != null) Text('Products mapped: ${_products!.length}'),
        if (_salesOrderLines != null)
          Text('Sales orders: ${_salesOrderLines!.length}'),
        if (_purchaseOrderLines != null)
          Text('Purchase orders: ${_purchaseOrderLines!.length}'),
        if (_inventoryTransactions != null)
          Text('Inventory transactions: ${_inventoryTransactions!.length}'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('inFlow Inventory Research'),
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: _parsedRows == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Welcome! Import your inFlow files to begin.',
                        style: TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _importFiles,
                        child: const Text('Import Files'),
                      ),
                      if (_importedDatasets.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('${_importedDatasets.length} file(s) imported',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 300,
                          width: 400,
                          child: ListView.builder(
                            itemCount: _importedDatasets.length,
                            itemBuilder: (context, index) {
                              final dataset = _importedDatasets[index];
                              return Card(
                                child: ListTile(
                                  title: Text(dataset.fileName),
                                  subtitle: Text(
                                      '${dataset.rowCount} rows · ${dataset.headers.length} columns'),
                                  onTap: () => _updateActiveDataset(dataset),
                                  selected: _activeDataset == dataset,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DropdownButton<String>(
                                  hint: const Text('Select column'),
                                  value: _searchColumn,
                                  items: _headers!
                                      .map((h) => DropdownMenuItem(
                                          value: h, child: Text(h)))
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _searchColumn = value;
                                      _selectedColumnStats = value != null &&
                                              _headers != null &&
                                              _parsedRows != null
                                          ? ColumnInspectorService
                                              .inspectColumns(_parsedRows!,
                                                  _headers!)[value]
                                          : null;
                                    });
                                    _filterRows();
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      labelText: 'Search',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      _searchQuery = value;
                                      _filterRows();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedColumnStats != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Card(
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Column: $_searchColumn',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            'Type: ${_selectedColumnStats!.type}'),
                                        Text(
                                            'Null/Empty Count: ${_selectedColumnStats!.nullCount}'),
                                        Text(
                                            'Unique Value Count: ${_selectedColumnStats!.uniqueCount}'),
                                        Text(
                                            'Sample Values: ${_selectedColumnStats!.sampleValues.join(", ")}'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: _verticalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            child: Scrollbar(
                              controller: _horizontalScrollController,
                              thumbVisibility: true,
                              notificationPredicate: (notification) =>
                                  notification.metrics.axis == Axis.horizontal,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: _headers!
                                      .map((h) => DataColumn(
                                          label: Text(h,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold))))
                                      .toList(),
                                  rows: (_filteredRows ?? []).map((row) {
                                    return DataRow(
                                      cells: _headers!
                                          .map((h) =>
                                              DataCell(Text(row[h] ?? '')))
                                          .toList(),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                if (_filteredRows != null && _headers != null) {
                                  try {
                                    final exportFileName =
                                        _fileName?.replaceFirst(
                                                RegExp(r'\.[^.]*$'), '') ??
                                            'export';
                                    CsvExportService.exportToCsv(
                                      _filteredRows!,
                                      _headers!,
                                      '$exportFileName-${DateTime.now().millisecondsSinceEpoch}.csv',
                                    );
                                    _showSuccessSnackBar(
                                        'CSV exported successfully!');
                                  } catch (e) {
                                    _showErrorDialog('Export Error',
                                        'Failed to export CSV: $e');
                                  }
                                } else {
                                  _showErrorDialog('Export Error',
                                      'No data available to export.');
                                }
                              },
                              child: const Text('Export as CSV'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _parsedRows = null;
                                  _filteredRows = null;
                                  _headers = null;
                                  _fileName = null;
                                  _searchQuery = '';
                                  _searchColumn = null;
                                  _products = null;
                                  _salesOrderLines = null;
                                  _purchaseOrderLines = null;
                                  _inventoryTransactions = null;
                                  _analysis = null;
                                  _importedDatasets = [];
                                  _activeDataset = null;
                                  _showMetadataPanel = false;
                                });
                              },
                              child: const Text('Clear All'),
                            ),
                            ElevatedButton(
                              onPressed: _importFiles,
                              child: const Text('Import More Files'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (_parsedRows != null)
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'metadata-toggle',
                    tooltip: _showMetadataPanel
                        ? 'Hide dataset summary'
                        : 'Show dataset summary',
                    onPressed: () {
                      setState(() {
                        _showMetadataPanel = !_showMetadataPanel;
                      });
                    },
                    child: Icon(
                        _showMetadataPanel ? Icons.close : Icons.info_outline),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: _showMetadataPanel
                        ? ConstrainedBox(
                            key: const ValueKey('metadataPanel'),
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Card(
                              elevation: 6,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: _buildMetadataContent(),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          if (_isImporting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Importing files... please wait'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
