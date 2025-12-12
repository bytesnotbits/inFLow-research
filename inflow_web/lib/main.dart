import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'models/imported_dataset.dart';
import 'models/inventory_transaction.dart';
import 'models/normalized_database.dart';
import 'models/product.dart';
import 'models/purchase_order_line.dart';
import 'models/reorder_setting.dart';
import 'models/sales_order_line.dart';
import 'models/stock_level.dart';
import 'services/column_inspector_service.dart';
import 'services/csv_export_service.dart';
import 'services/csv_parser_service.dart';
import 'services/data_transform_service.dart';
import 'services/dataset_classifier_service.dart';
import 'services/dataset_analysis_service.dart';
import 'services/file_import_service.dart';
import 'services/model_mapper_service.dart';
import 'services/normalized_database_service.dart';
import 'services/validation_service.dart';

const String _accessCode =
    String.fromEnvironment('INFLOW_ACCESS_CODE', defaultValue: 'research-demo');

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

enum _ColumnVisibilityAction { showAll, hideSelected, keepSelected }

class _ColumnVisibilityResult {
  final _ColumnVisibilityAction action;
  final Set<String> columns;

  const _ColumnVisibilityResult(this.action, this.columns);
}

enum ImportStatus { success, empty, invalid, error }

class ImportSummaryEntry {
  final String fileName;
  final ImportStatus status;
  final int rows;
  final int columns;
  final bool isReel;
  final String message;

  const ImportSummaryEntry({
    required this.fileName,
    required this.status,
    required this.rows,
    required this.columns,
    required this.isReel,
    required this.message,
  });
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
  Set<String>? _visibleColumns;
  bool _isImporting = false;
  final Map<String, _DatasetProcessingResult> _datasetProcessingCache = {};
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
  static const List<String> _initialLoadMessages = [
    'Bootstrapping normalized datasets...',
    'Dusting off the inventory archives...',
    'Crunching historical CSVs into shape...',
    'Almost there — prepping dashboards...',
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
  NormalizedDatabase? _normalizedDatabase;
  bool _isAuthorized = false;
  final TextEditingController _accessCodeController = TextEditingController();
  String? _accessError;
  bool _isVerifyingAccess = false;
  bool _isInitialLoad = true;
  Timer? _initialLoadMessageTimer;
  int _initialLoadMessageIndex = 0;
  String _initialLoadMessage = _initialLoadMessages.first;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
      _initialLoadSnackBar;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryLoadNormalizedDatabase();
    });
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _loadingMessageTimer?.cancel();
    _initialLoadMessageTimer?.cancel();
    _globalSearchDebounce?.cancel();
    _globalSearchController.dispose();
    _columnSearchController.dispose();
    _accessCodeController.dispose();
    _rowPulseController.dispose();
    super.dispose();
  }

  Future<void> _tryLoadNormalizedDatabase() async {
    if (!_isAuthorized || _normalizedDatabase != null || !_isInitialLoad) {
      return;
    }
    _startInitialLoadMessages();
    _showInitialLoadSnackBar();
    try {
      final normalized = await const NormalizedDatabaseService().load();
      if (!mounted) return;
      if (normalized != null) {
        _ingestNormalizedDatabase(normalized);
      } else {
        _showErrorDialog(
          'Startup Error',
          'Unable to load the normalized datasets. Try importing a file instead.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
      _stopInitialLoadMessages();
      _dismissInitialLoadSnackBar();
    }
  }

  void _ingestNormalizedDatabase(NormalizedDatabase normalized) {
    final bundles = _buildNormalizedDatasetBundles(normalized);
    final newBundles = bundles
        .where(
          (bundle) =>
              !_datasetProcessingCache.containsKey(bundle.dataset.fileName),
        )
        .toList();
    if (newBundles.isEmpty) {
      setState(() {
        _normalizedDatabase = normalized;
      });
      return;
    }
    setState(() {
      _normalizedDatabase = normalized;
      _importedDatasets = [
        ..._importedDatasets,
        ...newBundles.map((bundle) => bundle.dataset),
      ];
      for (final bundle in newBundles) {
        _datasetProcessingCache[bundle.dataset.fileName] = bundle.result;
      }
    });
    if (_activeDataset == null && newBundles.isNotEmpty) {
      _updateActiveDataset(newBundles.first.dataset);
    }
    _showSuccessSnackBar(
      'Loaded ${newBundles.length} normalized dataset${newBundles.length == 1 ? '' : 's'}.',
    );
  }

  Future<void> _importFiles() async {
    setState(() {
      _isImporting = true;
    });
    // Allow the loading UI to render before heavy work begins.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final summaries = <ImportSummaryEntry>[];
    final newDatasets = <ImportedDataset>[];
    ImportedDataset? lastImportedDataset;
    List<ImportSummaryEntry>? summaryToShow;
    ImportedDataset? datasetToActivate;
    try {
      final files = await FileImportService.pickFiles();
      if (files.isEmpty) {
        _showErrorDialog(
            'No file selected', 'Please select a CSV file to import.');
        return;
      }
      final hasLargeFile = files.any(
        (file) => file.size > _largeFileThresholdBytes,
      );
      _startLoadingMessages(hasLargeFile);

      for (final file in files) {
        final fileName = file.name;
        try {
          // Validate file
          final fileValidation =
              ValidationService.validateFile(fileName, file.size);
          if (!fileValidation.isValid) {
            summaries.add(
              ImportSummaryEntry(
                fileName: fileName,
                status: ImportStatus.invalid,
                rows: 0,
                columns: 0,
                isReel: false,
                message: fileValidation.message,
              ),
            );
            continue;
          }

          // Parse CSV off the main isolate
          var rows = await CsvParserService.parseCsvAsync(file);
          if (rows.isEmpty) {
            summaries.add(
              ImportSummaryEntry(
                fileName: fileName,
                status: ImportStatus.empty,
                rows: 0,
                columns: 0,
                isReel: false,
                message: 'File contains no data rows.',
              ),
            );
            continue;
          }

          // Validate parsed data
          final headers = rows.first.keys.toList();
          final dataValidation =
              ValidationService.validateCsvData(rows, headers);
          if (!dataValidation.isValid) {
            summaries.add(
              ImportSummaryEntry(
                fileName: fileName,
                status: ImportStatus.invalid,
                rows: rows.length,
                columns: headers.length,
                isReel: false,
                message: dataValidation.message,
              ),
            );
            continue;
          }

          // Guess common date columns
          final dateColumns =
              headers.where((k) => k.toLowerCase().contains('date')).toList();
          final isReelDataset =
              DatasetClassifierService.isLikelyReelDataset(fileName, rows);
          final processed = await compute(
            _processDataset,
            _DatasetProcessingPayload(
              rows: rows,
              dateColumns: dateColumns,
              isReel: isReelDataset,
            ),
          );
          _datasetProcessingCache[fileName] = processed;

          // Create dataset
          final dataset = ImportedDataset(
            fileName: fileName,
            importedAt: DateTime.now(),
            rows: processed.rows,
            headers: processed.headers,
          );
          newDatasets.add(dataset);
          lastImportedDataset = dataset;
          summaries.add(
            ImportSummaryEntry(
              fileName: fileName,
              status: ImportStatus.success,
              rows: dataset.rowCount,
              columns: dataset.headers.length,
              isReel: isReelDataset,
              message:
                  '${dataset.rowCount} row${dataset.rowCount == 1 ? '' : 's'}, ${dataset.headers.length} column${dataset.headers.length == 1 ? '' : 's'}',
            ),
          );
        } catch (e) {
          summaries.add(
            ImportSummaryEntry(
              fileName: fileName,
              status: ImportStatus.error,
              rows: 0,
              columns: 0,
              isReel: false,
              message: 'Unexpected error: $e',
            ),
          );
        }
      }

      if (newDatasets.isNotEmpty) {
        setState(() {
          _importedDatasets.addAll(newDatasets);
        });
        datasetToActivate = lastImportedDataset;
      }

      await _recomputeDatasetMatchCounts();
      _applyGlobalSearchToActiveDataset();

      final successCount = summaries
          .where((entry) => entry.status == ImportStatus.success)
          .length;
      if (successCount > 0) {
        _showSuccessSnackBar('$successCount file(s) imported successfully.');
      }
      final hasIssues = summaries.any(
        (entry) => entry.status != ImportStatus.success,
      );
      if (hasIssues || successCount > 0) {
        summaryToShow = List.unmodifiable(summaries);
      }
    } catch (e) {
      _showErrorDialog('Import Error', 'An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isImporting = false;
        _stopLoadingMessages();
      });
    }

    if (datasetToActivate != null && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      _updateActiveDataset(datasetToActivate);
    }
    if (summaryToShow != null && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      await _showImportSummaryDialog(summaryToShow);
    }
  }

  void _updateActiveDataset(ImportedDataset dataset) {
    final processed = _datasetProcessingCache[dataset.fileName];
    if (processed == null) {
      _showErrorDialog(
        'Dataset Not Ready',
        'Processing for ${dataset.fileName} is missing. Please re-import the file.',
      );
      return;
    }
    final baseRows = _globalSearchQuery.isEmpty
        ? processed.rows
        : _filterRowsByQuery(processed.rows, _globalSearchQuery);
    setState(() {
      _activeDataset = dataset;
      _parsedRows = processed.rows;
      _activeGlobalFilteredRows = baseRows;
      _filteredRows = null;
      _headers = processed.headers;
      _fileName = dataset.fileName;
      _searchQuery = '';
      _searchColumn = null;
      _columnSearchController.clear();
      _products = processed.products;
      _salesOrderLines = processed.salesOrderLines;
      _purchaseOrderLines = processed.purchaseOrderLines;
      _inventoryTransactions = processed.inventoryTransactions;
      _analysis = processed.analysis;
      _visibleColumns = null;
      _columnStatsCache.clear();
      _selectedColumnStats = null;
      _showMetadataPanel = false;
      _columnWidths = processed.headers
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

  Future<void> _showImportSummaryDialog(
    List<ImportSummaryEntry> entries,
  ) async {
    if (!mounted || entries.isEmpty) return;
    final successCount =
        entries.where((e) => e.status == ImportStatus.success).length;
    final emptyCount =
        entries.where((e) => e.status == ImportStatus.empty).length;
    final invalidCount =
        entries.where((e) => e.status == ImportStatus.invalid).length;
    final errorCount =
        entries.where((e) => e.status == ImportStatus.error).length;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import summary'),
          content: SizedBox(
            width: math.min(MediaQuery.of(context).size.width * 0.6, 520),
            height: math.min(MediaQuery.of(context).size.height * 0.6, 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Success: $successCount • Empty: $emptyCount • Invalid: $invalidCount • Errors: $errorCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Scrollbar(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            _statusIcon(entry.status),
                            color: _statusColor(entry.status),
                          ),
                          title: Text(
                            entry.fileName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(entry.message),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _statusLabel(entry.status),
                                style: TextStyle(
                                  color: _statusColor(entry.status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (entry.status == ImportStatus.success)
                                Text(
                                  '${entry.rows}×${entry.columns}${entry.isReel ? ' · Reel' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _statusLabel(ImportStatus status) {
    switch (status) {
      case ImportStatus.success:
        return 'Imported';
      case ImportStatus.empty:
        return 'Empty';
      case ImportStatus.invalid:
        return 'Invalid';
      case ImportStatus.error:
        return 'Error';
    }
  }

  Color _statusColor(ImportStatus status) {
    switch (status) {
      case ImportStatus.success:
        return Colors.green;
      case ImportStatus.empty:
        return Colors.orange;
      case ImportStatus.invalid:
        return Colors.deepOrange;
      case ImportStatus.error:
        return Colors.red;
    }
  }

  IconData _statusIcon(ImportStatus status) {
    switch (status) {
      case ImportStatus.success:
        return Icons.check_circle;
      case ImportStatus.empty:
        return Icons.inbox;
      case ImportStatus.invalid:
        return Icons.warning;
      case ImportStatus.error:
        return Icons.error;
    }
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
        _isRowCountWarningActive = rowCount > _rowCountWarningThreshold;
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
      _isRowCountWarningActive = rowCount > _rowCountWarningThreshold;
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

  List<String> get _displayedHeaders {
    if (_headers == null) return [];
    if (_visibleColumns == null) return _headers!;
    return _headers!
        .where((header) => _visibleColumns!.contains(header))
        .toList();
  }

  double _getColumnWidth(String header) {
    if (_headers == null || _columnWidths.isEmpty) {
      return _minColumnWidth;
    }
    final index = _headers!.indexOf(header);
    if (index >= 0 && index < _columnWidths.length) {
      return _columnWidths[index];
    }
    return _minColumnWidth;
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
              onPressed: _confirmClearAllDatasets,
              child: const Text('Reset Workspace'),
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: (!_isInitialLoad &&
                    _normalizedDatabase != null &&
                    _importedDatasets.isEmpty)
                ? _restoreNormalizedDatasets
                : null,
            icon: const Icon(Icons.replay),
            label: const Text('Reload Baseline Data'),
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
      final message = _globalSearchQuery.isNotEmpty && _visibleDatasets.isEmpty
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
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DropdownButton<String>(
                    hint: const Text('Select column'),
                    value: _searchColumn,
                    items: _displayedHeaders
                        .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _searchColumn = value;
                        _selectedColumnStats =
                            value != null ? _getColumnStats(value) : null;
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
                  IconButton(
                    tooltip: 'Column options',
                    icon: const Icon(Icons.view_column),
                    onPressed: _showColumnVisibilityDialog,
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
                onPressed: () async {
                  if (_filteredRows != null && _headers != null) {
                    try {
                      final exportFileName =
                          _fileName?.replaceFirst(RegExp(r'\.[^.]*$'), '') ??
                              'export';
                      final exported = await CsvExportService.exportToCsv(
                        _filteredRows!,
                        _headers!,
                        '$exportFileName-${DateTime.now().millisecondsSinceEpoch}.csv',
                      );
                      if (exported) {
                        _showSuccessSnackBar('CSV exported successfully!');
                      }
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
        final catalogWidth = (_catalogWidthFraction * totalWidth)
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
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  final currentWidth = _catalogWidthFraction * totalWidth;
                  final newWidth = (currentWidth + details.delta.dx).clamp(
                    minCatalogWidth,
                    maxCatalogWidth,
                  );
                  setState(() {
                    _catalogWidthFraction = newWidth / totalWidth;
                  });
                },
                child: SizedBox(
                  width: 24,
                  height: double.infinity,
                  child: Center(
                    child: Container(
                      width: 4,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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

  void _startInitialLoadMessages() {
    _initialLoadMessageTimer?.cancel();
    _initialLoadMessageIndex = 0;
    _initialLoadMessage = _initialLoadMessages.first;
    _initialLoadMessageTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        _initialLoadMessageIndex =
            (_initialLoadMessageIndex + 1) % _initialLoadMessages.length;
        _initialLoadMessage = _initialLoadMessages[_initialLoadMessageIndex];
      });
    });
  }

  void _stopInitialLoadMessages() {
    _initialLoadMessageTimer?.cancel();
    _initialLoadMessageTimer = null;
    _initialLoadMessageIndex = 0;
    _initialLoadMessage = _initialLoadMessages.first;
  }

  void _showInitialLoadSnackBar() {
    if (!mounted || _initialLoadSnackBar != null) return;
    _initialLoadSnackBar = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Loading normalized datasets...'),
        duration: Duration(hours: 1),
      ),
    );
  }

  void _dismissInitialLoadSnackBar() {
    _initialLoadSnackBar?.close();
    _initialLoadSnackBar = null;
  }

  void _onGlobalSearchChanged(String value) {
    _globalSearchDebounce?.cancel();
    _globalSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
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
      updatedMatches[dataset.fileName] =
          query.isEmpty ? dataset.rowCount : _countMatches(dataset.rows, query);
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
      _datasetProcessingCache.clear();
    });
    _syncRowCountWarningAnimation();
  }

  Future<void> _confirmClearAllDatasets() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset workspace?'),
        content: const Text(
          'This will remove every loaded dataset, including the preloaded normalized data. '
          'You can reload the baseline data afterward using the "Reload Baseline Data" button.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (shouldClear == true) {
      _clearAllDatasets();
      _showSuccessSnackBar('Workspace reset. Click "Reload Baseline Data" to restore defaults.');
    }
  }

  void _restoreNormalizedDatasets() {
    final normalized = _normalizedDatabase;
    if (normalized == null) {
      _showErrorDialog(
        'No baseline data',
        'The normalized database is unavailable. Please rerun the normalization script or import files manually.',
      );
      return;
    }
    _ingestNormalizedDatabase(normalized);
  }

  Future<void> _submitAccessCode() async {
    if (_isVerifyingAccess) return;
    setState(() {
      _isVerifyingAccess = true;
      _accessError = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final entered = _accessCodeController.text.trim();
    if (entered == _accessCode) {
      setState(() {
        _isAuthorized = true;
      });
      _tryLoadNormalizedDatabase();
    } else {
      setState(() {
        _accessError = 'Incorrect access code. Please try again.';
      });
    }
    if (mounted) {
      setState(() {
        _isVerifyingAccess = false;
      });
    }
  }

  Future<void> _showColumnVisibilityDialog() async {
    if (_headers == null || _headers!.isEmpty) return;
    final currentVisible = _visibleColumns ?? _headers!.toSet();
    final result = await showDialog<_ColumnVisibilityResult>(
      context: context,
      builder: (context) {
        final selected = <String>{};
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Column visibility'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: ListView(
                  children: _headers!.map((header) {
                    final isSelected = selected.contains(header);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(header),
                      onChanged: (value) {
                        setStateDialog(() {
                          if (value == true) {
                            selected.add(header);
                          } else {
                            selected.remove(header);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setStateDialog(() {
                      selected
                        ..clear()
                        ..addAll(currentVisible);
                    });
                  },
                  child: const Text('Select visible'),
                ),
                TextButton(
                  onPressed: () {
                    setStateDialog(() {
                      selected.clear();
                    });
                  },
                  child: const Text('Clear selection'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const _ColumnVisibilityResult(
                    _ColumnVisibilityAction.showAll,
                    {},
                  )),
                  child: const Text('Show all'),
                ),
                TextButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            _ColumnVisibilityResult(
                              _ColumnVisibilityAction.hideSelected,
                              Set<String>.from(selected),
                            ),
                          ),
                  child: const Text('Hide selected'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(
                            _ColumnVisibilityResult(
                              _ColumnVisibilityAction.keepSelected,
                              Set<String>.from(selected),
                            ),
                          ),
                  child: const Text('Keep only selected'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    switch (result.action) {
      case _ColumnVisibilityAction.showAll:
        setState(() {
          _visibleColumns = null;
        });
        break;
      case _ColumnVisibilityAction.hideSelected:
        final base = _visibleColumns ?? _headers!.toSet();
        final updated = base.difference(result.columns);
        setState(() {
          _visibleColumns = updated.isEmpty ? null : updated;
        });
        break;
      case _ColumnVisibilityAction.keepSelected:
        setState(() {
          _visibleColumns =
              result.columns.isEmpty ? null : Set<String>.from(result.columns);
        });
        break;
    }
    if (_visibleColumns != null &&
        _searchColumn != null &&
        !_visibleColumns!.contains(_searchColumn!)) {
      setState(() {
        _searchColumn = null;
        _selectedColumnStats = null;
        _columnSearchController.clear();
        _searchQuery = '';
      });
    }
    _filterRows();
  }

  Widget _buildDataTableRow({
    Map<String, String>? row,
    bool isHeader = false,
    bool isOdd = false,
  }) {
    final headers = _displayedHeaders;
    final backgroundColor = isHeader
        ? Colors.blueGrey.shade50
        : (isOdd ? Colors.grey.shade100 : Colors.white);
    return Container(
      color: backgroundColor,
      child: Row(
        children: List.generate(headers.length, (index) {
          final header = headers[index];
          final width = _getColumnWidth(header);
          final text = isHeader ? header : (row?[header] ?? '');
          final textWidget = Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: isHeader
                ? const TextStyle(
                    fontWeight: FontWeight.bold,
                  )
                : const TextStyle(fontSize: 13),
          );
          final cellChild = text.isNotEmpty
              ? Tooltip(
                  message: text,
                  waitDuration: const Duration(milliseconds: 500),
                  child: textWidget,
                )
              : textWidget;
          return SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: cellChild,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDataTableArea() {
    if (_headers == null) return const SizedBox.shrink();
    final headers = _displayedHeaders;
    final rows = _filteredRows ?? [];
    if (rows.isEmpty) {
      return const Center(child: Text('No rows match your current filters.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final headerWidth = headers.isNotEmpty
            ? headers
                .map(_getColumnWidth)
                .fold<double>(0, (prev, width) => prev + width)
            : headers.length * _minColumnWidth;
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

  List<_NormalizedDatasetBundle> _buildNormalizedDatasetBundles(
    NormalizedDatabase normalized,
  ) {
    final bundles = <_NormalizedDatasetBundle>[];

    void addBundle<T>({
      required String label,
      required List<NormalizedRecord<T>> records,
      required _DatasetProcessingResult Function(
        List<Map<String, String>> rows,
        List<String> headers,
        DatasetAnalysis analysis,
        List<T> values,
      ) buildResult,
    }) {
      final bundle = _createNormalizedDatasetBundle<T>(
        label: label,
        generatedAt: normalized.generatedAt,
        records: records,
        buildResult: buildResult,
      );
      if (bundle != null) {
        bundles.add(bundle);
      }
    }

    addBundle<Product>(
      label: 'Normalized Products',
      records: normalized.products,
      buildResult: (rows, headers, analysis, values) =>
          _DatasetProcessingResult(
        rows: rows,
        headers: headers,
        analysis: analysis,
        products: values,
        salesOrderLines: const [],
        purchaseOrderLines: const [],
        inventoryTransactions: const [],
      ),
    );

    addBundle<SalesOrderLine>(
      label: 'Normalized Sales Orders',
      records: normalized.salesOrderLines,
      buildResult: (rows, headers, analysis, values) =>
          _DatasetProcessingResult(
        rows: rows,
        headers: headers,
        analysis: analysis,
        products: const [],
        salesOrderLines: values,
        purchaseOrderLines: const [],
        inventoryTransactions: const [],
      ),
    );

    addBundle<PurchaseOrderLine>(
      label: 'Normalized Purchase Orders',
      records: normalized.purchaseOrderLines,
      buildResult: (rows, headers, analysis, values) =>
          _DatasetProcessingResult(
        rows: rows,
        headers: headers,
        analysis: analysis,
        products: const [],
        salesOrderLines: const [],
        purchaseOrderLines: values,
        inventoryTransactions: const [],
      ),
    );

    addBundle<InventoryTransaction>(
      label: 'Normalized Inventory Transactions',
      records: normalized.inventoryTransactions,
      buildResult: (rows, headers, analysis, values) =>
          _DatasetProcessingResult(
        rows: rows,
        headers: headers,
        analysis: analysis,
        products: const [],
        salesOrderLines: const [],
        purchaseOrderLines: const [],
        inventoryTransactions: values,
      ),
    );

    addBundle<StockLevel>(
      label: 'Normalized Stock Levels',
      records: normalized.stockLevels,
      buildResult: (rows, headers, analysis, values) =>
          _DatasetProcessingResult(
        rows: rows,
        headers: headers,
        analysis: analysis,
        products: const [],
        salesOrderLines: const [],
        purchaseOrderLines: const [],
        inventoryTransactions: const [],
      ),
    );

    addBundle<ReorderSetting>(
      label: 'Normalized Reorder Settings',
      records: normalized.reorderSettings,
      buildResult: (rows, headers, analysis, values) =>
          _DatasetProcessingResult(
        rows: rows,
        headers: headers,
        analysis: analysis,
        products: const [],
        salesOrderLines: const [],
        purchaseOrderLines: const [],
        inventoryTransactions: const [],
      ),
    );

    return bundles;
  }

  _NormalizedDatasetBundle? _createNormalizedDatasetBundle<T>({
    required String label,
    required DateTime generatedAt,
    required List<NormalizedRecord<T>> records,
    required _DatasetProcessingResult Function(
      List<Map<String, String>> rows,
      List<String> headers,
      DatasetAnalysis analysis,
      List<T> values,
    ) buildResult,
  }) {
    if (records.isEmpty) return null;
    final rows = _normalizedRecordsToRows(records);
    if (rows.isEmpty) return null;
    final headers = rows.first.keys.toList();
    final analysis = DatasetAnalysisService.analyzeDataset(rows, headers);
    final dataset = ImportedDataset(
      fileName: label,
      importedAt: generatedAt,
      rows: rows,
      headers: headers,
    );
    final values = records.map((record) => record.record).toList();
    final result = buildResult(rows, headers, analysis, values);
    return _NormalizedDatasetBundle(
      dataset: dataset,
      result: result,
    );
  }

  List<Map<String, String>> _normalizedRecordsToRows<T>(
    List<NormalizedRecord<T>> records,
  ) {
    final rows = <Map<String, String>>[];
    for (final normalized in records) {
      final row = <String, String>{
        'sourceFile': normalized.sourceFile,
        'sourceRow': normalized.sourceRow.toString(),
      };
      try {
        final dynamic payload = normalized.record;
        final dynamic jsonMap = (payload as dynamic).toJson();
        if (jsonMap is Map) {
          jsonMap.forEach((key, value) {
            row[key.toString()] = _stringifyValue(value);
          });
        }
      } catch (_) {
        // ignore — fall back to source fields only
      }
      rows.add(row);
    }
    return rows;
  }

  String _stringifyValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is num || value is bool) return value.toString();
    if (value is Iterable) {
      return value.map(_stringifyValue).join(', ');
    }
    return value.toString();
  }

  Widget _buildAccessGate() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('inFlow Inventory Research'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Access Required',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the shared access code to view normalized inventory data.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _accessCodeController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Access code',
                      errorText: _accessError,
                    ),
                    onSubmitted: (_) => _submitAccessCode(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isVerifyingAccess ? null : _submitAccessCode,
                      icon: const Icon(Icons.login),
                      label: _isVerifyingAccess
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialLoadingView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 72,
            ),
            const SizedBox(height: 12),
            const Text(
              'inFlow Inventory Research',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _initialLoadMessage,
                key: ValueKey(_initialLoadMessage),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return _buildAccessGate();
    }
    if (_isInitialLoad) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('inFlow Inventory Research'),
        ),
        body: _buildInitialLoadingView(),
      );
    }
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
                child: hasDatasets ? _buildSplitView() : _buildWelcomeContent(),
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

class _NormalizedDatasetBundle {
  final ImportedDataset dataset;
  final _DatasetProcessingResult result;

  const _NormalizedDatasetBundle({
    required this.dataset,
    required this.result,
  });
}

class _DatasetProcessingPayload {
  final List<Map<String, String>> rows;
  final List<String> dateColumns;
  final bool isReel;

  const _DatasetProcessingPayload({
    required this.rows,
    required this.dateColumns,
    required this.isReel,
  });
}

class _DatasetProcessingResult {
  final List<Map<String, String>> rows;
  final List<String> headers;
  final DatasetAnalysis analysis;
  final List<Product> products;
  final List<SalesOrderLine> salesOrderLines;
  final List<PurchaseOrderLine> purchaseOrderLines;
  final List<InventoryTransaction> inventoryTransactions;

  const _DatasetProcessingResult({
    required this.rows,
    required this.headers,
    required this.analysis,
    required this.products,
    required this.salesOrderLines,
    required this.purchaseOrderLines,
    required this.inventoryTransactions,
  });
}

_DatasetProcessingResult _processDataset(_DatasetProcessingPayload payload) {
  final transformed = DataTransformService.transformRows(
    payload.rows,
    dateColumns: payload.dateColumns,
    columnRenames: payload.isReel ? const {'Sublocation': 'ReelNumber'} : null,
  );
  final headers =
      transformed.isNotEmpty ? transformed.first.keys.toList() : <String>[];
  final analysis = DatasetAnalysisService.analyzeDataset(transformed, headers);
  final products = transformed
      .map(ModelMapperService.mapToProduct)
      .whereType<Product>()
      .toList();
  final salesOrderLines = transformed
      .map(ModelMapperService.mapToSalesOrderLine)
      .whereType<SalesOrderLine>()
      .toList();
  final purchaseOrderLines = transformed
      .map(ModelMapperService.mapToPurchaseOrderLine)
      .whereType<PurchaseOrderLine>()
      .toList();
  final inventoryTransactions = transformed
      .map(ModelMapperService.mapToInventoryTransaction)
      .whereType<InventoryTransaction>()
      .toList();
  return _DatasetProcessingResult(
    rows: transformed,
    headers: headers,
    analysis: analysis,
    products: products,
    salesOrderLines: salesOrderLines,
    purchaseOrderLines: purchaseOrderLines,
    inventoryTransactions: inventoryTransactions,
  );
}
