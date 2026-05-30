import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/legal_document_model.dart';

/// Кеши офлайн барои рӯйхат ва PDF-ҳои санадҳои меъёрию ҳуқуқӣ.
class LegalDocumentsCache {
  static const _pageKey = 'legal_documents_page_v1';
  static const _pdfDirName = 'legal_documents_pdfs';
  static const _siteBase = 'https://books.1week.tj';

  static String? normalizePdfUrl(String? raw) {
    if (raw == null) return null;
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('//')) {
      url = 'https:$url';
    } else if (url.startsWith('/')) {
      url = '$_siteBase$url';
    }
    if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'https://');
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.startsWith('/media/legal_documents/')) {
      return url;
    }
    return url;
  }

  static Future<bool> get hasNetwork async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  static Future<Directory> _pdfDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_pdfDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _pdfFileName(int documentId) => 'legal_doc_$documentId.pdf';

  static Future<void> savePage(LegalDocumentsPageData page) async {
    try {
      final box = Hive.box('cache');
      await box.put(_pageKey, jsonEncode(page.toJson()));
    } catch (e) {
      debugPrint('LegalDocumentsCache.savePage: $e');
    }
  }

  static Future<LegalDocumentsPageData?> loadPage() async {
    try {
      final box = Hive.box('cache');
      final raw = box.get(_pageKey);
      if (raw is String && raw.isNotEmpty) {
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          return LegalDocumentsPageData.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('LegalDocumentsCache.loadPage: $e');
    }
    return null;
  }

  static Future<String?> getCachedPdfPath(int documentId) async {
    if (documentId <= 0) return null;
    try {
      final file = File(
        '${(await _pdfDirectory()).path}/${_pdfFileName(documentId)}',
      );
      if (await file.exists()) {
        final size = await file.length();
        if (size > 0) return file.path;
      }
    } catch (e) {
      debugPrint('LegalDocumentsCache.getCachedPdfPath: $e');
    }
    return null;
  }

  static Future<Uint8List?> getCachedPdfBytes(int documentId) async {
    final path = await getCachedPdfPath(documentId);
    if (path == null) return null;
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Боргирӣ ва захира — URL ё файлҳои кешшударо бармегардонад.
  static Future<String?> downloadAndCachePdf({
    required int documentId,
    required String url,
  }) async {
    if (documentId <= 0) return null;

    final existing = await getCachedPdfPath(documentId);
    if (existing != null) return existing;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final file = File(
        '${(await _pdfDirectory()).path}/${_pdfFileName(documentId)}',
      );
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('LegalDocumentsCache.downloadAndCachePdf: $e');
      return null;
    }
  }

  /// Пас аз боркунии рӯйхат — ҳамаи PDF-ҳоро дар пасзамина захира мекунад.
  static void prefetchAll(
    List<LegalDocumentModel> documents,
    String? Function(String? url) normalizeUrl,
  ) {
    Future.microtask(() async {
      for (final doc in documents) {
        if (!doc.hasPdf || doc.id <= 0) continue;
        final url = normalizeUrl(doc.pdfUrl);
        if (url == null || url.isEmpty) continue;
        final cached = await getCachedPdfPath(doc.id);
        if (cached != null) continue;
        await downloadAndCachePdf(documentId: doc.id, url: url);
      }
    });
  }
}
