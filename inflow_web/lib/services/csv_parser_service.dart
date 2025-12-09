import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class CsvParserService {
  /// Parses a CSV file and returns a list of maps (header:value).
  static List<Map<String, String>> parseCsv(PlatformFile file) {
    final content = file.bytes != null
        ? utf8.decode(file.bytes!)
        : file.readStream != null
            ? utf8.decode(file.readStream!.toList().cast<int>())
            : '';
    if (content.isEmpty) return [];
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return [];
    final headers = _parseCsvLine(lines.first);
    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final values = _parseCsvLine(lines[i]);
      if (values.length == headers.length) {
        rows.add({for (var j = 0; j < headers.length; j++) headers[j]: values[j]});
      }
    }
    return rows;
  }

  static List<String> _parseCsvLine(String line) {
    // Basic CSV parsing, handles quoted fields
    final regex = RegExp(r'("[^"]*"|[^,]+)');
    return regex
        .allMatches(line)
        .map((m) => m.group(0)!.replaceAll('"', '').trim())
        .toList();
  }
}
