import 'package:flutter/services.dart' show rootBundle;

/// pdf.js аз assets — кор мекунад бе интернет.
class PdfJsAssets {
  static String? _lib;
  static String? _worker;

  static Future<void> ensureLoaded() async {
    if (_lib != null && _worker != null) return;
    _lib = await rootBundle.loadString('assets/pdfjs/pdf.min.js');
    _worker = await rootBundle.loadString('assets/pdfjs/pdf.worker.min.js');
  }

  static String get lib {
    final v = _lib;
    if (v == null) {
      throw StateError('PdfJsAssets.ensureLoaded() first');
    }
    return v;
  }

  static String get worker {
    final v = _worker;
    if (v == null) {
      throw StateError('PdfJsAssets.ensureLoaded() first');
    }
    return v;
  }
}
