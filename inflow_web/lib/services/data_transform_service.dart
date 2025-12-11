class DataTransformService {
  /// Normalizes date strings to ISO 8601 format (YYYY-MM-DD HH:mm:ss).
  static String normalizeDate(String dateStr) {
    // Try to parse common formats, fallback to original if parsing fails
    try {
      // Remove timezone info if present
      final cleaned = dateStr.replaceAll(RegExp(r' -\d{2}:\d{2}'), '');
      final date = DateTime.tryParse(cleaned);
      if (date != null) {
        return date.toIso8601String().replaceFirst('T', ' ').split('.').first;
      }
      // Try MM/DD/YYYY HH:mm:ss AM/PM
      final usFormat = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4}) (\d{1,2}):(\d{2}):(\d{2}) (AM|PM)');
      final match = usFormat.firstMatch(dateStr);
      if (match != null) {
        int month = int.parse(match.group(1)!);
        int day = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        int hour = int.parse(match.group(4)!);
        int minute = int.parse(match.group(5)!);
        int second = int.parse(match.group(6)!);
        String ampm = match.group(7)!;
        if (ampm == 'PM' && hour < 12) hour += 12;
        if (ampm == 'AM' && hour == 12) hour = 0;
        final dt = DateTime(year, month, day, hour, minute, second);
        return dt.toIso8601String().replaceFirst('T', ' ').split('.').first;
      }
    } catch (_) {}
    return dateStr;
  }

  /// Trims whitespace from all string values in a row.
  static Map<String, String> trimRow(Map<String, String> row) {
    return row.map((k, v) => MapEntry(k.trim(), v.trim()));
  }

  /// Applies transformations to all rows.
  static List<Map<String, String>> transformRows(
    List<Map<String, String>> rows, {
    List<String>? dateColumns,
    Map<String, String>? columnRenames,
  }) {
    return rows.map((row) {
      final trimmed = trimRow(row);
      final normalized = Map<String, String>.from(trimmed);
      if (dateColumns != null) {
        for (final col in dateColumns) {
          if (normalized.containsKey(col)) {
            normalized[col] = normalizeDate(normalized[col]!);
          }
        }
      }
      if (columnRenames == null || columnRenames.isEmpty) {
        return normalized;
      }
      final renamed = <String, String>{};
      normalized.forEach((key, value) {
        final newKey = columnRenames[key] ?? key;
        renamed[newKey] = value;
      });
      return renamed;
    }).toList();
  }
}
