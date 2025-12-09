
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

  Future<void> _importFiles() async {
    try {
      final files = await FileImportService.pickFiles();
      if (files.isEmpty) {
        _showErrorDialog('No file selected', 'Please select a CSV file to import.');
        return;
      }

      final file = files.first;

      // Validate file
      final fileValidation = ValidationService.validateFile(file.name, file.size);
      if (!fileValidation.isValid) {
        _showErrorDialog('Invalid File', fileValidation.message);
        return;
      }

      // Parse CSV
      var rows = CsvParserService.parseCsv(file);

      // Validate parsed data
      final dataValidation = ValidationService.validateCsvData(rows, rows.isNotEmpty ? rows.first.keys.toList() : []);
      if (!dataValidation.isValid) {
        _showErrorDialog('Invalid CSV Data', dataValidation.message);
        return;
      }

      // Guess common date columns
      final dateColumns = rows.first.keys.where((k) => k.toLowerCase().contains('date')).toList();
      rows = DataTransformService.transformRows(rows, dateColumns: dateColumns);

      // Map to domain models (try all types, filter nulls)
      final products = rows.map(ModelMapperService.mapToProduct).whereType<Product>().toList();
      final salesOrderLines = rows.map(ModelMapperService.mapToSalesOrderLine).whereType<SalesOrderLine>().toList();
      final purchaseOrderLines = rows.map(ModelMapperService.mapToPurchaseOrderLine).whereType<PurchaseOrderLine>().toList();
      final inventoryTransactions = rows.map(ModelMapperService.mapToInventoryTransaction).whereType<InventoryTransaction>().toList();

      // Analyze dataset
      final analysis = DatasetAnalysisService.analyzeDataset(rows, rows.first.keys.toList());

      setState(() {
        _parsedRows = rows;
        _filteredRows = rows;
        _headers = rows.first.keys.toList();
        _fileName = file.name;
        _searchQuery = '';
        _searchColumn = null;
        _products = products;
        _salesOrderLines = salesOrderLines;
        _purchaseOrderLines = purchaseOrderLines;
        _inventoryTransactions = inventoryTransactions;
        _analysis = analysis;
      });

      _showSuccessSnackBar('File imported successfully!');
    } catch (e) {
      _showErrorDialog('Import Error', 'An unexpected error occurred: $e');
    }
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
        _selectedColumnStats = _searchColumn != null && _headers != null && _parsedRows != null
            ? ColumnInspectorService.inspectColumns(_parsedRows!, _headers!)[_searchColumn!]
            : null;
      });
      return;
    }
    setState(() {
      _filteredRows = _parsedRows!.where((row) {
        final value = row[_searchColumn!]?.toLowerCase() ?? '';
        return value.contains(_searchQuery.toLowerCase());
      }).toList();
      _selectedColumnStats = _searchColumn != null && _headers != null && _parsedRows != null
          ? ColumnInspectorService.inspectColumns(_parsedRows!, _headers!)[_searchColumn!]
          : null;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('inFlow Inventory Research'),
      ),
      body: Center(
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
                ],
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preview: $_fileName', style: const TextStyle(fontSize: 18)),
                        if (_analysis != null) ...[
                          Text('Rows: ${_analysis!.rowCount}, Columns: ${_analysis!.columnCount}'),
                          if (_analysis!.dateRanges.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Date Ranges:', style: const TextStyle(fontWeight: FontWeight.bold)),
                            for (final entry in _analysis!.dateRanges.entries)
                              Text('  ${entry.key}: ${entry.value.range} (${entry.value.count} dates)'),
                          ],
                        ],
                        const SizedBox(height: 8),
                        if (_products != null)
                          Text('Products mapped: ${_products!.length}'),
                        if (_salesOrderLines != null)
                          Text('SalesOrderLines mapped: ${_salesOrderLines!.length}'),
                        if (_purchaseOrderLines != null)
                          Text('PurchaseOrderLines mapped: ${_purchaseOrderLines!.length}'),
                        if (_inventoryTransactions != null)
                          Text('InventoryTransactions mapped: ${_inventoryTransactions!.length}'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DropdownButton<String>(
                              hint: const Text('Select column'),
                              value: _searchColumn,
                              items: _headers!.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _searchColumn = value;
                                  _selectedColumnStats = value != null && _headers != null && _parsedRows != null
                                      ? ColumnInspectorService.inspectColumns(_parsedRows!, _headers!)[value]
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Column: $_searchColumn', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Type: ${_selectedColumnStats!.type}'),
                                    Text('Null/Empty Count: ${_selectedColumnStats!.nullCount}'),
                                    Text('Unique Value Count: ${_selectedColumnStats!.uniqueCount}'),
                                    Text('Sample Values: ${_selectedColumnStats!.sampleValues.join(", ")}'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: _headers!
                            .map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold))))
                            .toList(),
                        rows: (_filteredRows ?? []).take(20).map((row) {
                          return DataRow(
                            cells: _headers!.map((h) => DataCell(Text(row[h] ?? ''))).toList(),
                          );
                        }).toList(),
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
                                final exportFileName = _fileName?.replaceFirst(RegExp(r'\.[^.]*$'), '') ?? 'export';
                                CsvExportService.exportToCsv(
                                  _filteredRows!,
                                  _headers!,
                                  '$exportFileName-${DateTime.now().millisecondsSinceEpoch}.csv',
                                );
                                _showSuccessSnackBar('CSV exported successfully!');
                              } catch (e) {
                                _showErrorDialog('Export Error', 'Failed to export CSV: $e');
                              }
                            } else {
                              _showErrorDialog('Export Error', 'No data available to export.');
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
                            });
                          },
                          child: const Text('Import Another File'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
