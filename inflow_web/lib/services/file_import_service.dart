import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class FileImportService {
  /// Opens a file picker and returns the selected files.
  static Future<List<PlatformFile>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );
    if (result != null) {
      return result.files;
    }
    return [];
  }

  /// Reads the file bytes for further parsing.
  static Future<Uint8List?> readFileBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes;
    }
    if (file.path != null) {
      return await FilePicker.platform.readFile(file.path!);
    }
    return null;
  }
}
