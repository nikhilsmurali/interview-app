import 'file_saver_io.dart'
    if (dart.library.html) 'file_saver_web.dart' as platform;

class FileSaver {
  static Future<void> savePdfFile(List<int> bytes, String fileName) async {
    await platform.saveAndLaunchFile(bytes, fileName);
  }
}
