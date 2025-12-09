
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'services/file_import_service.dart';
import 'services/csv_parser_service.dart';
import 'services/data_transform_service.dart';

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
  List<Map<String, String>>? _parsedRows;
  List<Map<String, String>>? _filteredRows;
  List<String>? _headers;
  String? _fileName;
  String _searchQuery = '';
  String? _searchColumn;

  Future<void> _importFiles() async {
    final files = await FileImportService.pickFiles();
    if (files.isNotEmpty) {
      // Only parse the first file for now
      final file = files.first;
      var rows = CsvParserService.parseCsv(file);
      // Guess common date columns
      final dateColumns = rows.isNotEmpty
          ? rows.first.keys.where((k) => k.toLowerCase().contains('date')).toList()
          : <String>[];
      rows = DataTransformService.transformRows(rows, dateColumns: dateColumns);
      setState(() {
        _parsedRows = rows;
        _filteredRows = rows;
        _headers = rows.isNotEmpty ? rows.first.keys.toList() : [];
        _fileName = file.name;
        _searchQuery = '';
        _searchColumn = null;
      });
    }
  }

  void _filterRows() {
    if (_parsedRows == null || _searchQuery.isEmpty || _searchColumn == null) {
      setState(() {
        _filteredRows = _parsedRows;
      });
      return;
    }
    setState(() {
      _filteredRows = _parsedRows!.where((row) {
        final value = row[_searchColumn!]?.toLowerCase() ?? '';
        return value.contains(_searchQuery.toLowerCase());
      }).toList();
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
                    child: Text('Preview: $_fileName', style: const TextStyle(fontSize: 18)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Row(
                      children: [
                        DropdownButton<String>(
                          hint: const Text('Select column'),
                          value: _searchColumn,
                          items: _headers!.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                          onChanged: (value) {
                            setState(() {
                              _searchColumn = value;
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
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _parsedRows = null;
                          _filteredRows = null;
                          _headers = null;
                          _fileName = null;
                          _searchQuery = '';
                          _searchColumn = null;
                        });
                      },
                      child: const Text('Import Another File'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
