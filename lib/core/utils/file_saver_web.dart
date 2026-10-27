import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveAndLaunchFile(List<int> bytes, String fileName) async {
  final Uint8List uint8list = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = html.Blob([uint8list], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);

  // Keep URL active for 10 seconds so browser download stream completes fully
  Future.delayed(const Duration(seconds: 10), () {
    html.Url.revokeObjectUrl(url);
  });
}
