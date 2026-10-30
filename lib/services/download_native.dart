import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _downloadChannel = MethodChannel('com.apschool.attendance/downloads');

Future<String?> saveDownloadFile(Uint8List bytes, String fileName, String mimeType) async {
  if (Platform.isAndroid) {
    return _downloadChannel.invokeMethod<String>('saveFile', {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': mimeType,
    });
  }

  final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
