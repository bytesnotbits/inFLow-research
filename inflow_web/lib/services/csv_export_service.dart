import 'dart:convert';
import 'dart:html' as html;

class CsvExportService {
  /// Exports a list of maps to CSV format and triggers download.
  static void exportToCsv(List<Map<String, String>> rows, List<String> headers, String fileName) {
    if (rows.isEmpty || headers.isEmpty) return;

    final csvContent = _generateCsv(rows, headers);
    _downloadCsv(csvContent, fileName);
  }

  static String _generateCsv(List<Map<String, String>> rows, List<String> headers) {
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

  static void _downloadCsv(String content, String fileName) {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
