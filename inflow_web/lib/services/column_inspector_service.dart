class ColumnInspectorService {
  static Map<String, ColumnStats> inspectColumns(List<Map<String, String>> rows, List<String> headers) {
    final stats = <String, ColumnStats>{};
    for (final header in headers) {
      final values = rows.map((row) => row[header]).toList();
      stats[header] = ColumnStats.fromValues(values);
    }
    return stats;
  }
}

class ColumnStats {
  final String type;
  final int nullCount;
  final int uniqueCount;
  final List<String> sampleValues;

  ColumnStats({
    required this.type,
    required this.nullCount,
    required this.uniqueCount,
    required this.sampleValues,
  });

  factory ColumnStats.fromValues(List<String?> values) {
    final nonNullValues = values.where((v) => v != null && v.trim().isNotEmpty).toList();
    final nullCount = values.length - nonNullValues.length;
    final uniqueCount = nonNullValues.toSet().length;
    final sampleValues = nonNullValues.take(5).toList();
    final type = _detectType(nonNullValues);
    return ColumnStats(
      type: type,
      nullCount: nullCount,
      uniqueCount: uniqueCount,
      sampleValues: sampleValues,
    );
  }

  static String _detectType(List<String> values) {
    if (values.isEmpty) return 'Unknown';
    final numCount = values.where((v) => double.tryParse(v) != null).length;
    final dateCount = values.where((v) => DateTime.tryParse(v) != null).length;
    if (dateCount > values.length * 0.7) return 'Date';
    if (numCount > values.length * 0.7) return 'Number';
    return 'Text';
  }
}
