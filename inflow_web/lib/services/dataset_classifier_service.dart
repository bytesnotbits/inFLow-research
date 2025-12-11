class DatasetClassifierService {
  static bool isLikelyReelDataset(
    String fileName,
    List<Map<String, String>> rows,
  ) {
    if (_isExplicitReelFile(fileName)) return true;
    if (rows.isEmpty) return false;
    final normalizedFileName = _normalizeIdentifier(
      _stripExtension(fileName),
    );
    if (normalizedFileName.isEmpty) return false;

    final sublocationValues = rows
        .map((row) => row['Sublocation'])
        .whereType<String>()
        .map(_normalizeIdentifier)
        .where((value) => value.isNotEmpty)
        .toList();
    if (sublocationValues.isEmpty) return false;

    final uniqueValues = sublocationValues.toSet();
    if (uniqueValues.length == 1) {
      final value = uniqueValues.first;
      if (_matchesFileName(normalizedFileName, value)) return true;
      if (_looksLikeReelCode(value) && _looksLikeReelCode(normalizedFileName)) {
        return true;
      }
    }

    final dominant = _findDominantValue(sublocationValues);
    if (dominant == null) return false;
    final dominantValue = dominant.key;
    final dominanceRatio = dominant.value;
    if (dominanceRatio >= 0.95 && _matchesFileName(normalizedFileName, dominantValue)) {
      return true;
    }
    return false;
  }

  static String _stripExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
  }

  static bool _isExplicitReelFile(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    return normalized.startsWith('reel ');
  }

  static String _normalizeIdentifier(String input) {
    return input
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  static bool _matchesFileName(String fileName, String value) {
    if (value.isEmpty) return false;
    return fileName.contains(value) || value.contains(fileName);
  }

  static bool _looksLikeReelCode(String value) {
    if (value.length < 4 || value.length > 16) return false;
    final hasLetter = RegExp(r'[A-Z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    return hasLetter && hasDigit;
  }

  static MapEntry<String, double>? _findDominantValue(List<String> values) {
    if (values.isEmpty) return null;
    final counts = <String, int>{};
    for (final value in values) {
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final total = values.length;
    final dominantEntry = counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return MapEntry(dominantEntry.key, dominantEntry.value / total);
  }
}
