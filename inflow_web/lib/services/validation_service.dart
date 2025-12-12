class ValidationService {
  static const int maxFileSize = 33 * 1024 * 1024; // 33MB
  static const List<String> supportedExtensions = ['csv'];

  static ValidationResult validateFile(String? fileName, int? fileSizeBytes) {
    if (fileName == null || fileName.isEmpty) {
      return ValidationResult(isValid: false, message: 'File name is empty.');
    }

    final extension = fileName.split('.').last.toLowerCase();
    if (!supportedExtensions.contains(extension)) {
      return ValidationResult(
        isValid: false,
        message:
            'Unsupported file format: .$extension. Supported formats: ${supportedExtensions.join(', ')}',
      );
    }

    if (fileSizeBytes != null && fileSizeBytes > maxFileSize) {
      final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
      return ValidationResult(
        isValid: false,
        message: 'File size ($sizeMb MB) exceeds maximum limit (33 MB).',
      );
    }

    return ValidationResult(isValid: true, message: 'File is valid.');
  }

  static ValidationResult validateCsvData(
      List<Map<String, String>> rows, List<String> headers) {
    if (rows.isEmpty) {
      return ValidationResult(
          isValid: false, message: 'CSV file contains no data rows.');
    }

    if (headers.isEmpty) {
      return ValidationResult(
          isValid: false, message: 'CSV file contains no headers.');
    }

    return ValidationResult(isValid: true, message: 'CSV data is valid.');
  }
}

class ValidationResult {
  final bool isValid;
  final String message;

  ValidationResult({required this.isValid, required this.message});
}
