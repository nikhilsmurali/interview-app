import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ResumeParserService {
  static Future<String> parseFile(PlatformFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Selected file has no data.');
    }

    final ext = (file.extension ?? '').toLowerCase();

    if (ext == 'pdf') {
      try {
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final String text = PdfTextExtractor(document).extractText();
        document.dispose();
        final cleanText = _cleanText(text);
        if (cleanText.isNotEmpty) return cleanText;
      } catch (e) {
        debugPrint('PdfTextExtractor error: $e. Falling back to byte text scanner.');
      }
      return _extractAsciiStrings(bytes);
    } else if (ext == 'txt' || ext == 'md') {
      try {
        return _cleanText(utf8.decode(bytes, allowMalformed: true));
      } catch (_) {
        return _cleanText(latin1.decode(bytes));
      }
    } else if (ext == 'docx' || ext == 'doc') {
      // DOCX contains XML files inside a ZIP or raw XML text
      final text = _extractAsciiStrings(bytes);
      if (text.isNotEmpty) return text;
    }

    // Generic fallback for any other file
    return _extractAsciiStrings(bytes);
  }

  static String _extractAsciiStrings(List<int> bytes) {
    final buffer = StringBuffer();
    final wordBuffer = StringBuffer();

    for (int b in bytes) {
      // Readable ASCII characters or newline/space
      if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b == 9) {
        wordBuffer.writeCharCode(b);
      } else {
        if (wordBuffer.length > 3) {
          final word = wordBuffer.toString();
          // Filter out typical zip / binary headers
          if (!word.startsWith('PK') && !word.contains('xmlns')) {
            buffer.write('$word ');
          }
        }
        wordBuffer.clear();
      }
    }

    if (wordBuffer.length > 3) {
      buffer.write(wordBuffer.toString());
    }

    return _cleanText(buffer.toString());
  }

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'(\r\n|\r|\n)+'), '\n')
        .trim();
  }
}
