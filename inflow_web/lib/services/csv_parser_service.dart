import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../utils/csv_utils.dart';

class CsvParserService {
  /// Parses a CSV file and returns a list of maps (header:value).
  static List<Map<String, String>> parseCsv(PlatformFile file) {
    if (file.bytes == null) return [];
    return CsvUtils.parseBytes(file.bytes!);
  }

  /// Parses a CSV file on a background isolate to avoid blocking the UI.
  static Future<List<Map<String, String>>> parseCsvAsync(
      PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) return [];
    return compute(CsvUtils.parseBytes, bytes);
  }
}
