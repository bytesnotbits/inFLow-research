import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

/// Shared helpers for parsing CSV content into header/value maps.
class CsvUtils {
  const CsvUtils._();

  /// Parses UTF8 CSV bytes.
  static List<Map<String, String>> parseBytes(Uint8List bytes) {
    final content = utf8.decode(bytes);
    return parseContent(content);
  }

  /// Parses CSV string content into a list of maps (header:value).
  static List<Map<String, String>> parseContent(String content) {
    if (content.isEmpty) return [];
    final sanitized = content
        .replaceFirst(RegExp(r'^\ufeff'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final csvRows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(sanitized);
    if (csvRows.isEmpty) return [];

    final headers =
        csvRows.first.map((value) => (value ?? '').toString().trim()).toList();
    final rows = <Map<String, String>>[];
    for (final row in csvRows.skip(1)) {
      if (row.isEmpty) continue;
      final mappedRow = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        final header = headers[i];
        if (header.isEmpty) continue;
        final value =
            i < row.length && row[i] != null ? row[i].toString().trim() : '';
        mappedRow[header] = value;
      }
      if (mappedRow.isNotEmpty) {
        rows.add(mappedRow);
      }
    }
    return rows;
  }
}
