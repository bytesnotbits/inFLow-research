import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CsvParserService {
  /// Parses a CSV file and returns a list of maps (header:value).
  static List<Map<String, String>> parseCsv(PlatformFile file) {
    var content = file.bytes != null ? utf8.decode(file.bytes!) : '';
    if (content.isEmpty) return [];
    content = content
        .replaceFirst(RegExp(r'^\ufeff'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final csvRows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
    if (csvRows.isEmpty) return [];

    final headers = csvRows.first.map((value) => (value ?? '').toString().trim()).toList();
    final rows = <Map<String, String>>[];

    for (final row in csvRows.skip(1)) {
      if (row.isEmpty) continue;
      final mappedRow = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        final header = headers[i];
        if (header.isEmpty) continue;
        final value = i < row.length && row[i] != null ? row[i].toString().trim() : '';
        mappedRow[header] = value;
      }
      if (mappedRow.isNotEmpty) {
        rows.add(mappedRow);
      }
    }

    return rows;
  }
}
