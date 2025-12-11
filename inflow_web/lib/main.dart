import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models/imported_dataset.dart';
import 'models/inventory_transaction.dart';
import 'models/product.dart';
import 'models/purchase_order_line.dart';
import 'models/sales_order_line.dart';
import 'services/column_inspector_service.dart';
import 'services/csv_export_service.dart';
import 'services/csv_parser_service.dart';
import 'services/data_transform_service.dart';
import 'services/dataset_classifier_service.dart';
import 'services/dataset_analysis_service.dart';
import 'services/file_import_service.dart';
import 'services/model_mapper_service.dart';
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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
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
  final Map<String, ColumnStats> _columnStatsCache = {};
  List<Map<String, String>>? _activeGlobalFilteredRows;
  String _globalSearchQuery = '';
  final TextEditingController _globalSearchController = TextEditingController();
  final TextEditingController _columnSearchController = TextEditingController();
  Timer? _globalSearchDebounce;
  final Map<String, int> _datasetMatchCounts = {};
  double _catalogWidthFraction = 0.4;
  bool _isImporting = false;
  bool _showMetadataPanel = false;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  List<double> _columnWidths = [];
  static const double _minColumnWidth = 140;
  static const int _largeFileThresholdBytes = 5 * 1024 * 1024;
  static const String _largeFileIntroMessage =
      'Heads up! That file is over 5 MB — this could take a moment.';
  static const List<String> _largeFileFollowUpMessages = [
    "This file's really heavy. Maybe I need to work out more.",
    "Parsing file. I love this! Crunching numbers is my thing!",
    'Still working over here — promise the app has not frozen.',
  ];
  Timer? _loadingMessageTimer;
  int _loadingMessageIndex = 0;
  String _loadingMessage = 'Importing files... please wait';
  static const int _rowCountWarningThreshold = 10000;
  bool _isRowCountWarningActive = false;
  late final AnimationController _rowPulseController;
  late final Animation<Color?> _rowPulseColor;

  // Multi-file support
  List<ImportedDataset> _importedDatasets = [];
  ImportedDataset? _activeDataset;

  @override
  void initState() {
    super.initState();
    _rowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rowPulseColor = ColorTween(
      begin: Colors.red.shade400,
      end: Colors.red.shade900,
    ).animate(
      CurvedAnimation(
        parent: _rowPulseController,
        curve: Curves.easeInOut,
      ),
    );
    _globalSearchController.text = _globalSearchQuery;
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _loadingMessageTimer?.cancel();
    _globalSearchDebounce?.cancel();
    _globalSearchController.dispose();
    _columnSearchController.dispose();
    _rowPulseController.dispose();
    super.dispose();
  }

  Future<void> _importFiles() async {
    setState(() {
      _isImporting = true;
    });
    // Allow the loading UI to render before heavy work begins.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    try {
      final files = await FileImportService.pickFiles();
      if (files.isEmpty) {
        _showErrorDialog(
            'No file selected', 'Please select a CSV file to import.');
        return;
      }
      final hasLargeFile = files.any(
        (file) => (file.size ?? 0) > _largeFileThresholdBytes,
      );
      _startLoadingMessages(hasLargeFile);

      for (final file in files) {
        // Validate file
        final fileValidation =
            ValidationService.validateFile(file.name, file.size);
        if (!fileValidation.isValid) {
          _showErrorDialog(
              'Invalid File: ${file.name}', fileValidation.message);
          continue;
        }

        // Parse CSV off the main isolate
        var rows = await CsvParserService.parseCsvAsync(file);

        // Validate parsed data
        final dataValidation = ValidationService.validateCsvData(
            rows, rows.isNotEmpty ? rows.first.keys.toList() : []);
        if (!dataValidation.isValid) {
          _showErrorDialog(
              'Invalid CSV Data: ${file.name}', dataValidation.message);
          continue;
        }

        // Guess common date columns
        final dateColumns = rows.isNotEmpty
            ? rows.first.keys
                .where((k) => k.toLowerCase().contains('date'))
                .toList()
            : <String>[];
        final isReelDataset =
            DatasetClassifierService.isLikelyReelDataset(file.name, rows);
        rows = DataTransformService.transformRows(
          rows,
          dateColumns: dateColumns,
          columnRenames: isReelDataset
              ? const {'Sublocation': 'ReelNumber'}
              : null,
        );

        // Create dataset
        final dataset = ImportedDataset(
          fileName: file.name,
          importedAt: DateTime.now(),
          rows: rows,
          headers: rows.isNotEmpty ? rows.first.keys.toList() : <String>[],
        );

        setState(() {
          _importedDatasets.add(dataset);
        });
        _updateActiveDataset(dataset);
      }

      await _recomputeDatasetMatchCounts();
      _applyGlobalSearchToActiveDataset();

      if (_importedDatasets.isNotEmpty) {
        _showSuccessSnackBar(
            '${_importedDatasets.length} file(s) imported successfully!');
      }
    } catch (e) {
      _showErrorDialog('Import Error', 'An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isImporting = false;
        _stopLoadingMessages();
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
    final baseRows = _globalSearchQuery.isEmpty
        ? dataset.rows
        : _filterRowsByQuery(dataset.rows, _globalSearchQuery);
    setState(() {
      _activeDataset = dataset;
      _parsedRows = dataset.rows;
      _activeGlobalFilteredRows = baseRows;
      _filteredRows = null;
      _headers = dataset.headers;
      _fileName = dataset.fileName;
      _searchQuery = '';
      _searchColumn = null;
      _columnSearchController.clear();
      _products = products;
      _salesOrderLines = salesOrderLines;
      _purchaseOrderLines = purchaseOrderLines;
      _inventoryTransactions = inventoryTransactions;
      _analysis = analysis;
      _columnStatsCache.clear();
      _selectedColumnStats = null;
      _showMetadataPanel = false;
      _columnWidths = dataset.headers
          .map(
            (header) => math.max<double>(
              _minColumnWidth,
              header.length * 9,
            ),
          )
          .toList();
    });
    _filterRows(baseRows: baseRows);
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

  void _filterRows({List<Map<String, String>>? baseRows}) {
    if (_parsedRows == null) {
      setState(() {
        _filteredRows = null;
        _selectedColumnStats = null;
        _isRowCountWarningActive = false;
      });
      _syncRowCountWarningAnimation();
      return;
    }
    final rows = baseRows ?? _activeGlobalFilteredRows ?? _parsedRows!;
    if (_searchQuery.isEmpty || _searchColumn == null) {
      final rowCount = rows.length;
      setState(() {
        _filteredRows = rows;
        _selectedColumnStats =
            _searchColumn != null ? _getColumnStats(_searchColumn!) : null;
        _isRowCountWarningActive =
            rowCount > _rowCountWarningThreshold;
      });
      _syncRowCountWarningAnimation();
      return;
    }
    final filtered = rows.where((row) {
      final value = row[_searchColumn!]?.toLowerCase() ?? '';
      return value.contains(_searchQuery.toLowerCase());
    }).toList();
    final rowCount = filtered.length;
    setState(() {
      _filteredRows = filtered;
      _selectedColumnStats =
          _searchColumn != null ? _getColumnStats(_searchColumn!) : null;
      _isRowCountWarningActive =
          rowCount > _rowCountWarningThreshold;
    });
    _syncRowCountWarningAnimation();
  }

  ColumnStats? _getColumnStats(String column) {
    if (_parsedRows == null) return null;
    if (_columnStatsCache.containsKey(column)) {
      return _columnStatsCache[column];
    }
    final stats = ColumnInspectorService.inspectColumn(_parsedRows!, column);
    _columnStatsCache[column] = stats;
    return stats;
  }

  void _syncRowCountWarningAnimation() {
    if (_isRowCountWarningActive) {
      if (!_rowPulseController.isAnimating) {
        _rowPulseController.repeat(reverse: true);
      }
    } else {
      if (_rowPulseController.isAnimating) {
        _rowPulseController.stop();
      }
      _rowPulseController.reset();
    }
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

  Widget _buildRowCountIndicator() {
    final rowCount = _filteredRows?.length ?? 0;
    if (!_isRowCountWarningActive) {
      return Text(
        'Rows: $rowCount',
        style: TextStyle(
          color: Colors.grey.shade600,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _rowPulseController,
      builder: (context, child) {
        final color = _rowPulseColor.value ?? Colors.red;
        return Text(
          'Rows: $rowCount',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: _importFiles,
            child: const Text('Import Files'),
          ),
          const SizedBox(width: 8),
          if (_importedDatasets.isNotEmpty)
            OutlinedButton(
              onPressed: _clearAllDatasets,
              child: const Text('Clear All'),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _globalSearchController,
              enabled: _importedDatasets.isNotEmpty,
              decoration: InputDecoration(
                labelText: 'Search across datasets',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _globalSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearGlobalSearch,
                      )
                    : null,
              ),
              onChanged: _onGlobalSearchChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatasetCard(ImportedDataset dataset) {
    final matchCount =
        _datasetMatchCounts[dataset.fileName] ?? dataset.rowCount;
    final isSelected = _activeDataset?.fileName == dataset.fileName;
    final isReel = dataset.fileName.toLowerCase().startsWith('reel ');
    final isLarge = dataset.rowCount > _rowCountWarningThreshold;
    final matchLabel = _globalSearchQuery.isEmpty
        ? '${dataset.rowCount} rows'
        : '$matchCount match${matchCount == 1 ? '' : 'es'}';
    final columnsLabel = '${dataset.headers.length} columns';
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: () => _updateActiveDataset(dataset),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dataset.fileName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.visibility, size: 16, color: Colors.blue),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(matchLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(columnsLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (isReel)
                    Chip(
                      label: const Text('Reel'),
                      backgroundColor: Colors.orange.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (isLarge)
                    Chip(
                      label: const Text('Large'),
                      backgroundColor: Colors.red.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Imported ${dataset.importedAt.toLocal().toIso8601String().split('T').first}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatasetCatalogPane() {
    if (_importedDatasets.isEmpty) {
      return _buildWelcomeContent();
    }
    final datasets = _visibleDatasets;
    if (datasets.isEmpty) {
      return Center(
        child: Text(
          'No datasets contain "$_globalSearchQuery".',
          style: const TextStyle(fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      itemCount: datasets.length,
      itemBuilder: (context, index) {
        final dataset = datasets[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: _buildDatasetCard(dataset),
        );
      },
    );
  }

  Widget _buildWelcomeContent() {
    return Center(
      child: Column(
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
      ),
    );
  }

  Widget _buildDetailPane() {
    if (_activeDataset == null || _parsedRows == null) {
      if (_importedDatasets.isEmpty) {
        return _buildWelcomeContent();
      }
      final message = _globalSearchQuery.isNotEmpty &&
              _visibleDatasets.isEmpty
          ? 'No datasets contain "$_globalSearchQuery".'
          : 'Select a dataset card to view its data.';
      return Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DropdownButton<String>(
                    hint: const Text('Select column'),
                    value: _searchColumn,
                    items: _headers!
                        .map((h) =>
                            DropdownMenuItem(value: h, child: Text(h)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _searchColumn = value;
                        _selectedColumnStats = value != null
                            ? _getColumnStats(value)
                            : null;
                      });
                      _filterRows();
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _columnSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Search within column',
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
              const SizedBox(height: 8),
              _buildRowCountIndicator(),
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
                          Text('Column: $_searchColumn',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text('Type: ${_selectedColumnStats!.type}'),
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
        Expanded(child: _buildDataTableArea()),
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
                          _fileName?.replaceFirst(RegExp(r'\.[^.]*$'), '') ??
                              'export';
                      CsvExportService.exportToCsv(
                        _filteredRows!,
                        _headers!,
                        '$exportFileName-${DateTime.now().millisecondsSinceEpoch}.csv',
                      );
                      _showSuccessSnackBar(
                          'CSV exported successfully!');
                    } catch (e) {
                      _showErrorDialog(
                          'Export Error', 'Failed to export CSV: $e');
                    }
                  } else {
                    _showErrorDialog(
                        'Export Error', 'No data available to export.');
                  }
                },
                child: const Text('Export as CSV'),
              ),
              ElevatedButton(
                onPressed: _importFiles,
                child: const Text('Import More Files'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSplitView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final minCatalogWidth = math.min(240.0, totalWidth * 0.5);
        final minDetailWidth = math.min(360.0, totalWidth * 0.6);
        final maxCatalogWidth = math.max(
          minCatalogWidth,
          totalWidth - minDetailWidth,
        );
        final catalogWidth =
            (_catalogWidthFraction * totalWidth)
                .clamp(minCatalogWidth, maxCatalogWidth);
        final detailWidth = totalWidth - catalogWidth;
        return Row(
          children: [
            SizedBox(
              width: catalogWidth,
              child: Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: _buildDatasetCatalogPane(),
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                final currentWidth = _catalogWidthFraction * totalWidth;
                final newWidth =
                    (currentWidth + details.delta.dx).clamp(
                  minCatalogWidth,
                  maxCatalogWidth,
                );
                setState(() {
                  _catalogWidthFraction = newWidth / totalWidth;
                });
              },
              child: SizedBox(
                width: 12,
                height: double.infinity,
                child: Center(
                  child: Container(
                    width: 2,
                    height: double.infinity,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: detailWidth,
              child: Card(
                margin: const EdgeInsets.only(
                  top: 8,
                  right: 8,
                  bottom: 8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildDetailPane(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startLoadingMessages(bool hasLargeFile) {
    _loadingMessageTimer?.cancel();
    _loadingMessageIndex = 0;
    if (hasLargeFile) {
      if (mounted) {
        setState(() {
          _loadingMessage = _largeFileIntroMessage;
        });
      } else {
        _loadingMessage = _largeFileIntroMessage;
      }
      _loadingMessageTimer =
          Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted) return;
        setState(() {
          _loadingMessage = _largeFileFollowUpMessages[
              _loadingMessageIndex % _largeFileFollowUpMessages.length];
          _loadingMessageIndex++;
        });
      });
    } else {
      if (mounted) {
        setState(() {
          _loadingMessage = 'Importing files... please wait';
        });
      } else {
        _loadingMessage = 'Importing files... please wait';
      }
    }
  }

  void _stopLoadingMessages() {
    _loadingMessageTimer?.cancel();
    _loadingMessageTimer = null;
    _loadingMessageIndex = 0;
    _loadingMessage = 'Importing files... please wait';
  }

  void _onGlobalSearchChanged(String value) {
    _globalSearchDebounce?.cancel();
    _globalSearchDebounce =
        Timer(const Duration(milliseconds: 300), () async {
      final query = value.trim();
      if (!mounted) return;
      setState(() {
        _globalSearchQuery = query;
      });
      await _recomputeDatasetMatchCounts();
      _applyGlobalSearchToActiveDataset();
    });
  }

  void _clearGlobalSearch() {
    _globalSearchDebounce?.cancel();
    _globalSearchController.clear();
    setState(() {
      _globalSearchQuery = '';
    });
    _recomputeDatasetMatchCounts();
    _applyGlobalSearchToActiveDataset();
  }

  Future<void> _recomputeDatasetMatchCounts() async {
    final query = _globalSearchQuery;
    final updatedMatches = <String, int>{};
    for (final dataset in _importedDatasets) {
      updatedMatches[dataset.fileName] = query.isEmpty
          ? dataset.rowCount
          : _countMatches(dataset.rows, query);
    }
    if (!mounted) return;
    setState(() {
      _datasetMatchCounts
        ..clear()
        ..addAll(updatedMatches);
    });
  }

  int _countMatches(List<Map<String, String>> rows, String query) {
    if (query.isEmpty) return rows.length;
    final lowerQuery = query.toLowerCase();
    var count = 0;
    for (final row in rows) {
      if (row.values.any(
        (value) => value.toLowerCase().contains(lowerQuery),
      )) {
        count++;
      }
    }
    return count;
  }

  void _applyGlobalSearchToActiveDataset() {
    if (_activeDataset == null) {
      setState(() {
        _activeGlobalFilteredRows = null;
      });
      _filterRows();
      return;
    }
    final baseRows = _globalSearchQuery.isEmpty
        ? _activeDataset!.rows
        : _filterRowsByQuery(_activeDataset!.rows, _globalSearchQuery);
    setState(() {
      _activeGlobalFilteredRows = baseRows;
    });
    _filterRows(baseRows: baseRows);
  }

  List<Map<String, String>> _filterRowsByQuery(
    List<Map<String, String>> rows,
    String query,
  ) {
    if (query.isEmpty) return rows;
    final lowerQuery = query.toLowerCase();
    return rows.where((row) {
      return row.values.any(
        (value) => value.toLowerCase().contains(lowerQuery),
      );
    }).toList();
  }

  List<ImportedDataset> get _visibleDatasets {
    if (_globalSearchQuery.isEmpty) {
      return _importedDatasets;
    }
    return _importedDatasets
        .where(
          (dataset) => (_datasetMatchCounts[dataset.fileName] ?? 0) > 0,
        )
        .toList();
  }

  void _clearAllDatasets() {
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
      _columnWidths = [];
      _activeGlobalFilteredRows = null;
      _datasetMatchCounts.clear();
      _globalSearchQuery = '';
      _globalSearchController.clear();
      _columnSearchController.clear();
      _isRowCountWarningActive = false;
      _selectedColumnStats = null;
      _columnStatsCache.clear();
    });
    _syncRowCountWarningAnimation();
  }

  Widget _buildDataTableRow({
    Map<String, String>? row,
    bool isHeader = false,
    bool isOdd = false,
  }) {
    final headers = _headers ?? [];
    final backgroundColor = isHeader
        ? Colors.blueGrey.shade50
        : (isOdd ? Colors.grey.shade100 : Colors.white);
    return Container(
      color: backgroundColor,
      child: Row(
        children: List.generate(headers.length, (index) {
          final header = headers[index];
          final width = index < _columnWidths.length
              ? _columnWidths[index]
              : _minColumnWidth;
          final text = isHeader ? header : (row?[header] ?? '');
          return SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: isHeader
                    ? const TextStyle(
                        fontWeight: FontWeight.bold,
                      )
                    : const TextStyle(fontSize: 13),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDataTableArea() {
    if (_headers == null) return const SizedBox.shrink();
    final rows = _filteredRows ?? [];
    if (rows.isEmpty) {
      return const Center(child: Text('No rows match your current filters.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final headerWidth = _columnWidths.isNotEmpty
            ? _columnWidths.reduce((value, element) => value + element)
            : _headers!.length * _minColumnWidth;
        final tableWidth = math.max(constraints.maxWidth, headerWidth);
        return Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  _buildDataTableRow(isHeader: true),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _verticalScrollController,
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          return _buildDataTableRow(
                            row: rows[index],
                            isOdd: index.isOdd,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDatasets = _importedDatasets.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('inFlow Inventory Research'),
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              _buildTopControls(),
              Expanded(
                child: hasDatasets
                    ? _buildSplitView()
                    : _buildWelcomeContent(),
              ),
            ],
          ),
          if (_activeDataset != null && _parsedRows != null)
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
              child: Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
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
