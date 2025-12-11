import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class CsvParserService {
  /// Parses a CSV file and returns a list of maps (header:value).
  static List<Map<String, String>> parseCsv(PlatformFile file) {
    if (file.bytes == null) return [];
    return _parseCsvBytes(file.bytes!);
  }

  /// Parses a CSV file on a background isolate to avoid blocking the UI.
  static Future<List<Map<String, String>>> parseCsvAsync(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) return [];
    return compute(_parseCsvBytes, bytes);
  }
}

List<Map<String, String>> _parseCsvBytes(Uint8List bytes) {
  var content = utf8.decode(bytes);
  return _parseCsvContent(content);
}

List<Map<String, String>> _parseCsvContent(String content) {
  if (content.isEmpty) return [];
  content = content
      .replaceFirst(RegExp(r'^\ufeff'), '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final csvRows =
      const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
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
