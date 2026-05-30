import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/legal_document_model.dart';
import 'legal_documents_cache_io.dart'
    if (dart.library.html) 'legal_documents_cache_io_stub.dart' as pdf_storage;

/// Кеши офлайн барои рӯйхат ва PDF-ҳои санадҳои меъёрию ҳуқуқӣ.
class LegalDocumentsCache {
  static const _pageKey = 'legal_documents_page_v1';
  static const _siteBase = 'https://books.1week.tj';

  static final Map<int, Uint8List> _memoryPdfBytes = {};
  static final Map<int, Future<String?>> _downloadsInFlight = {};

  static String _hivePdfKey(int documentId) => 'legal_pdf_v1_$documentId';

  /// Бе async — агар PDF аллакай дар хотир бошад.
  static Uint8List? getMemoryPdfBytesSync(int documentId) {
    if (documentId <= 0) return null;
    final mem = _memoryPdfBytes[documentId];
    if (mem != null && mem.isNotEmpty) return mem;
    return null;
  }

  static bool isPdfReadyInMemory(int documentId) =>
      getMemoryPdfBytesSync(documentId) != null;

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
      // Мустақим /media/... — ҳамон тавр мемонад (файл дар MEDIA)
      return url;
    }
    if (uri != null && uri.path.contains('/api/legal-documents/')) {
      return url;
    }
    return url;
  }

  static Future<bool> get hasNetwork async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

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

  static Future<Uint8List?> _loadPdfFromHive(int documentId) async {
    try {
      final box = Hive.box('cache');
      final raw = box.get(_hivePdfKey(documentId));
      if (raw is Uint8List && raw.isNotEmpty) return raw;
      if (raw is List && raw.isNotEmpty) {
        return Uint8List.fromList(raw.cast<int>());
      }
      if (raw is String && raw.isNotEmpty) {
        return base64Decode(raw);
      }
    } catch (e) {
      debugPrint('LegalDocumentsCache._loadPdfFromHive: $e');
    }
    return null;
  }

  static Future<void> _savePdfToHive(int documentId, Uint8List bytes) async {
    try {
      final box = Hive.box('cache');
      await box.put(_hivePdfKey(documentId), bytes);
    } catch (e) {
      debugPrint('LegalDocumentsCache._savePdfToHive: $e');
    }
  }

  static Future<bool> _hasPersistentPdf(int documentId) async {
    if (kIsWeb) {
      final bytes = await _loadPdfFromHive(documentId);
      return bytes != null && bytes.isNotEmpty;
    }
    final path = await pdf_storage.filePdfPath(documentId);
    return path != null;
  }

  /// Дар Web null бармегардонад (танҳо bytes).
  static Future<String?> getCachedPdfPath(int documentId) async {
    if (documentId <= 0 || kIsWeb) return null;
    return pdf_storage.filePdfPath(documentId);
  }

  static Future<Uint8List?> getCachedPdfBytes(int documentId) async {
    if (documentId <= 0) return null;
    final mem = _memoryPdfBytes[documentId];
    if (mem != null && mem.isNotEmpty) return mem;

    Uint8List? bytes;
    if (kIsWeb) {
      bytes = await _loadPdfFromHive(documentId);
    } else {
      bytes = await pdf_storage.readFilePdf(documentId);
    }

    if (bytes != null && bytes.isNotEmpty) {
      _memoryPdfBytes[documentId] = bytes;
    }
    return bytes;
  }

  static void putMemoryPdfBytes(int documentId, Uint8List bytes) {
    if (documentId > 0 && bytes.isNotEmpty) {
      _memoryPdfBytes[documentId] = bytes;
    }
  }

  static Future<String?> downloadAndCachePdf({
    required int documentId,
    required String url,
  }) async {
    if (documentId <= 0) return null;

    final inFlight = _downloadsInFlight[documentId];
    if (inFlight != null) return inFlight;

    if (await _hasPersistentPdf(documentId)) {
      await getCachedPdfBytes(documentId);
      return kIsWeb ? 'hive:$documentId' : await getCachedPdfPath(documentId);
    }

    final task = _downloadAndCachePdfImpl(documentId: documentId, url: url);
    _downloadsInFlight[documentId] = task;
    try {
      return await task;
    } finally {
      _downloadsInFlight.remove(documentId);
    }
  }

  static Future<String?> _downloadAndCachePdfImpl({
    required int documentId,
    required String url,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(minutes: 5));
      if (response.statusCode == 404) {
        debugPrint('LegalDocumentsCache: PDF 404 for doc $documentId');
        return null;
      }
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final bytes = response.bodyBytes;
      _memoryPdfBytes[documentId] = bytes;

      if (kIsWeb) {
        await _savePdfToHive(documentId, bytes);
        return 'hive:$documentId';
      }

      return await pdf_storage.writeFilePdf(documentId, bytes);
    } catch (e) {
      debugPrint('LegalDocumentsCache.downloadAndCachePdf: $e');
      return null;
    }
  }

  static Future<void> prefetchDocument(LegalDocumentModel doc) async {
    if (!doc.hasPdf || doc.id <= 0) return;
    if (isPdfReadyInMemory(doc.id)) return;

    if (await _hasPersistentPdf(doc.id)) {
      await getCachedPdfBytes(doc.id);
      return;
    }

    final url = normalizePdfUrl(doc.pdfUrl);
    if (url == null || url.isEmpty) return;
    if (!await hasNetwork) return;

    await downloadAndCachePdf(documentId: doc.id, url: url);
  }

  static void warmAllPdfMemory(List<LegalDocumentModel> documents) {
    Future.microtask(() async {
      for (final doc in documents) {
        if (!doc.hasPdf || doc.id <= 0) continue;
        if (_memoryPdfBytes.containsKey(doc.id)) continue;
        await getCachedPdfBytes(doc.id);
      }
    });
  }

  static void prefetchAll(
    List<LegalDocumentModel> documents,
    String? Function(String? url) normalizeUrl,
  ) {
    Future.microtask(() async {
      warmAllPdfMemory(documents);

      if (!await hasNetwork) return;

      final pending = <LegalDocumentModel>[];
      for (final doc in documents) {
        if (!doc.hasPdf || doc.id <= 0) continue;
        if (isPdfReadyInMemory(doc.id)) continue;
        if (await _hasPersistentPdf(doc.id)) continue;
        final u = normalizeUrl(doc.pdfUrl);
        if (u == null || u.isEmpty) continue;
        pending.add(doc);
      }

      const workers = 3;
      var index = 0;
      Future<void> worker() async {
        while (index < pending.length) {
          final i = index++;
          final doc = pending[i];
          final u = normalizeUrl(doc.pdfUrl);
          if (u == null) continue;
          await downloadAndCachePdf(documentId: doc.id, url: u);
        }
      }

      await Future.wait(List.generate(workers, (_) => worker()));
    });
  }
}
