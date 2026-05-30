import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../services/legal_documents_cache.dart';
import '../widgets/pdf_js_viewer.dart';
import 'web_pdf_view.dart';

/// PDF-ро дар дохили барнома намоиш медиҳад.
class DocumentPdfScreen extends StatefulWidget {
  final String title;
  final String? assetPath;
  final String? remoteUrl;
  final int? documentId;

  const DocumentPdfScreen({
    super.key,
    required this.title,
    this.assetPath,
    this.remoteUrl,
    this.documentId,
  });

  @override
  State<DocumentPdfScreen> createState() => _DocumentPdfScreenState();

  static String? normalizePdfUrl(String? raw) =>
      LegalDocumentsCache.normalizePdfUrl(raw);
}

class _DocumentPdfScreenState extends State<DocumentPdfScreen> {
  final GlobalKey<PdfJsViewerState> _viewerKey = GlobalKey();

  bool _isLoading = true;
  String? _error;
  double _zoom = 1.0;
  Uint8List? _pdfBytes;
  String? _pdfFilePath;
  String? _resolvedRemoteUrl;

  @override
  void initState() {
    super.initState();
    _resolvedRemoteUrl = LegalDocumentsCache.normalizePdfUrl(widget.remoteUrl);
    _loadPdfData();
  }

  Future<void> _loadPdfData() async {
    try {
      final docId = widget.documentId ?? 0;
      final remote = _resolvedRemoteUrl;

      if (docId > 0) {
        final cachedPath = await LegalDocumentsCache.getCachedPdfPath(docId);
        if (cachedPath != null && cachedPath.isNotEmpty) {
          if (mounted) {
            setState(() {
              _pdfFilePath = cachedPath;
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (remote != null && remote.isNotEmpty) {
        if (docId > 0) {
          final path = await LegalDocumentsCache.downloadAndCachePdf(
            documentId: docId,
            url: remote,
          ).timeout(const Duration(minutes: 3));
          if (path != null && !path.startsWith('hive:')) {
            if (mounted) {
              setState(() {
                _pdfFilePath = path;
                _isLoading = false;
              });
            }
            return;
          }
          if (path != null) {
            final bytes = await LegalDocumentsCache.getCachedPdfBytes(docId);
            if (bytes != null && bytes.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _pdfBytes = bytes;
                  _isLoading = false;
                });
              }
              return;
            }
          }
        } else {
          final response = await http
              .get(Uri.parse(remote))
              .timeout(const Duration(minutes: 3));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            if (mounted) {
              setState(() {
                _pdfBytes = response.bodyBytes;
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      final asset = widget.assetPath?.trim();
      if (asset != null && asset.isNotEmpty) {
        final data = await rootBundle.load(asset);
        if (mounted) {
          setState(() {
            _pdfBytes = data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              'PDF дар сервер ёфт нашуд (404).\nДар админка файлро бор кунед ё sync_legal_documents иҷро кунед.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'PDF бор карда нашуд. Интернетро санҷед ва такрор кунед.';
        });
      }
    }
  }

  bool get _hasPdfSource =>
      (_pdfFilePath != null && _pdfFilePath!.isNotEmpty) ||
      (_pdfBytes != null && _pdfBytes!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        actions: [
          if (!kIsWeb && _hasPdfSource) ...[
            IconButton(
              tooltip: 'Хурд кардан',
              onPressed: _zoom > 0.75 ? () => _setZoom(_zoom - 0.15) : null,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: 'Калон кардан',
              onPressed: _zoom < 2.5 ? () => _setZoom(_zoom + 0.15) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Боркунии PDF...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                    _pdfBytes = null;
                    _pdfFilePath = null;
                  });
                  _loadPdfData();
                },
                child: const Text('Такрор кардан'),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb) {
      final remote = _resolvedRemoteUrl;
      if (remote != null && remote.isNotEmpty) {
        return WebPdfView(url: remote);
      }
      return const Center(
        child: Text('PDF ё ссылка дар админка сабт нашудааст.'),
      );
    }

    if (!_hasPdfSource) {
      return const Center(
        child: Text('PDF бор карда нашуд.'),
      );
    }

    return PdfJsViewer(
      key: _viewerKey,
      filePath: _pdfFilePath,
      bytes: _pdfBytes,
      zoom: _zoom,
    );
  }

  Future<void> _setZoom(double value) async {
    final next = value.clamp(0.75, 2.5);
    setState(() => _zoom = next);
    await _viewerKey.currentState?.setZoom(_zoom);
  }
}
