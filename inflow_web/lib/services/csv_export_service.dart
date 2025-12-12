import 'dart:async';
import 'dart:convert';

import 'csv_download_stub.dart'
    if (dart.library.html) 'csv_download_web.dart'
    if (dart.library.io) 'csv_download_io.dart';

class CsvExportService {
  /// Exports the provided rows to CSV and returns whether a file was saved.
  static Future<bool> exportToCsv(
      List<Map<String, String>> rows, List<String> headers, String fileName) async {
    if (rows.isEmpty || headers.isEmpty) return false;

    final csvContent = _generateCsv(rows, headers);
    final bytes = utf8.encode(csvContent);
    return downloadCsvBytes(bytes, fileName);
  }

  static String _generateCsv(
      List<Map<String, String>> rows, List<String> headers) {
    final buffer = StringBuffer();

    // Write headers
    buffer.writeln(headers.map(_escapeCsvField).join(','));

    // Write rows
    for (final row in rows) {
      final values = headers.map((h) => row[h] ?? '');
      buffer.writeln(values.map(_escapeCsvField).join(','));
    }

    return buffer.toString();
  }

  static String _escapeCsvField(String field) {
    // Escape quotes and wrap in quotes if field contains comma, quote, or newline
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

}
