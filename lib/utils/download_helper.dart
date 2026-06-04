import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_mobile.dart';

class DownloadHelper {
  static Future<bool> downloadTimetable({
    required String fileName,
    required String content,
  }) async {
    try {
      if (kIsWeb) {
        await downloadFileImpl(fileName: fileName, content: content);
        return true;
      } else {
        await Clipboard.setData(ClipboardData(text: content));
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
