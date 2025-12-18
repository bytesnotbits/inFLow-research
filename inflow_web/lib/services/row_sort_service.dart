class RowSortService {
  /// Returns a new list of rows sorted by date (newest first by default).
  static List<Map<String, String>> sortByDate(
    List<Map<String, String>> rows, {
    List<String>? preferredColumns,
    bool descending = true,
  }) {
    if (rows.length <= 1) return rows;
    final columns = _resolveDateColumns(rows, preferredColumns);
    if (columns.isEmpty) return rows;
    final sorted = List<Map<String, String>>.from(rows);
    sorted.sort((a, b) => _compareRows(a, b, columns, descending));
    return sorted;
  }

  static int _compareRows(
    Map<String, String> a,
    Map<String, String> b,
    List<String> columns,
    bool descending,
  ) {
    final aDate = _extractDate(a, columns);
    final bDate = _extractDate(b, columns);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return descending ? 1 : -1;
    if (bDate == null) return descending ? -1 : 1;
    final cmp = aDate.compareTo(bDate);
    return descending ? -cmp : cmp;
  }

  static DateTime? _extractDate(
    Map<String, String> row,
    List<String> columns,
  ) {
    for (final column in columns) {
      final value = row[column];
      final parsed = _tryParseDate(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    DateTime? parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;
    final normalized = trimmed.replaceAll(' ', 'T');
    if (normalized != trimmed) {
      parsed = DateTime.tryParse(normalized);
    }
    return parsed;
  }

  static List<String> _resolveDateColumns(
    List<Map<String, String>> rows,
    List<String>? preferredColumns,
  ) {
    if (rows.isEmpty) return const [];
    final resolved = <String>[];
    final keyLookup = <String, String>{};
    for (final key in rows.first.keys) {
      keyLookup[key.toLowerCase()] = key;
    }
    if (preferredColumns != null && preferredColumns.isNotEmpty) {
      for (final candidate in preferredColumns) {
        final match = keyLookup[candidate.toLowerCase()];
        if (match != null && !resolved.contains(match)) {
          resolved.add(match);
        }
      }
    }
    if (resolved.isEmpty) {
      for (final key in rows.first.keys) {
        final lower = key.toLowerCase();
        if (lower.contains('date') || lower.contains('timestamp')) {
          resolved.add(key);
        }
      }
    }
    return resolved;
  }
}
