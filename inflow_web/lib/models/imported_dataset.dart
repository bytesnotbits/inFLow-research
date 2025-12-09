class ImportedDataset {
  final String fileName;
  final DateTime importedAt;
  final List<Map<String, String>> rows;
  final List<String> headers;
  final int rowCount;

  ImportedDataset({
    required this.fileName,
    required this.importedAt,
    required this.rows,
    required this.headers,
  }) : rowCount = rows.length;
}
