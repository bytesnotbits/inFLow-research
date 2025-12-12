import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<bool> downloadCsvBytes(List<int> bytes, String fileName) async {
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Save CSV file',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );

  if (savePath == null) {
    return false;
  }

  final file = File(savePath);
  await file.writeAsBytes(bytes, flush: true);
  return true;
}
