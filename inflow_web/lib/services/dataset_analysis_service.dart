class DatasetAnalysisService {
  static DatasetAnalysis analyzeDataset(List<Map<String, String>> rows, List<String> headers) {
    final rowCount = rows.length;
    final columnCount = headers.length;
    final dateRanges = _extractDateRanges(rows, headers);

    return DatasetAnalysis(
      rowCount: rowCount,
      columnCount: columnCount,
      dateRanges: dateRanges,
    );
  }

  static Map<String, DateRange> _extractDateRanges(List<Map<String, String>> rows, List<String> headers) {
    final dateRanges = <String, DateRange>{};
    for (final header in headers) {
      if (header.toLowerCase().contains('date')) {
        final dates = rows
            .map((row) => DateTime.tryParse(row[header] ?? ''))
            .whereType<DateTime>()
            .toList();
        if (dates.isNotEmpty) {
          dates.sort();
          dateRanges[header] = DateRange(
            earliest: dates.first,
            latest: dates.last,
            count: dates.length,
          );
        }
      }
    }
    return dateRanges;
  }
}

class DatasetAnalysis {
  final int rowCount;
  final int columnCount;
  final Map<String, DateRange> dateRanges;

  DatasetAnalysis({
    required this.rowCount,
    required this.columnCount,
    required this.dateRanges,
  });
}

class DateRange {
  final DateTime earliest;
  final DateTime latest;
  final int count;

  DateRange({
    required this.earliest,
    required this.latest,
    required this.count,
  });

  String get range => '${earliest.toIso8601String().split('T').first} to ${latest.toIso8601String().split('T').first}';
}
