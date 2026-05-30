import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/pdf_js_assets.dart';
import '../utils/pdf_js_viewer_html.dart';

/// Намоиши PDF бо pdf.js — zoom ва ҷустуҷӯ тавассути JS.
class PdfJsViewer extends StatefulWidget {
  final Uint8List? bytes;
  final String? filePath;
  final double zoom;

  const PdfJsViewer({
    super.key,
    this.bytes,
    this.filePath,
    this.zoom = 1.0,
  }) : assert(bytes != null || filePath != null);

  @override
  State<PdfJsViewer> createState() => PdfJsViewerState();
}

class PdfJsViewerState extends State<PdfJsViewer> {
  InAppWebViewController? _controller;
  String? _tempPdfPath;

  @override
  void dispose() {
    final temp = _tempPdfPath;
    if (temp != null) {
      try {
        File(temp).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        supportZoom: true,
        builtInZoomControls: false,
        displayZoomControls: false,
        verticalScrollBarEnabled: true,
        horizontalScrollBarEnabled: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        allowFileAccess: true,
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
      ),
      onWebViewCreated: (c) {
        _controller = c;
        _openPdf(c);
      },
    );
  }

  Future<String?> _resolvePdfPath() async {
    final existing = widget.filePath?.trim();
    if (existing != null && existing.isNotEmpty) {
      final file = File(existing);
      if (await file.exists() && await file.length() > 0) {
        return existing;
      }
    }

    final bytes = widget.bytes;
    if (bytes == null || bytes.isEmpty) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/pdf_view_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    _tempPdfPath = file.path;
    return file.path;
  }

  Future<void> _openPdf(InAppWebViewController controller) async {
    final pdfPath = await _resolvePdfPath();
    if (pdfPath == null) return;

    await PdfJsAssets.ensureLoaded();

    final pdfFile = File(pdfPath);
    final viewerDir = pdfFile.parent;
    const viewerName = 'pdf_viewer_shell.html';
    final viewerFile = File('${viewerDir.path}/$viewerName');

    final shell = buildPdfJsShellHtml(
      pdfJsLib: PdfJsAssets.lib,
      pdfWorker: PdfJsAssets.worker,
      initialZoom: widget.zoom,
      pdfOpenUrl: Uri.file(pdfPath).toString(),
    );
    await viewerFile.writeAsString(shell, flush: true);

    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri.uri(Uri.file(viewerFile.path)),
      ),
    );
  }

  Future<void> setZoom(double zoom) async {
    final c = _controller;
    if (c == null) return;
    await c.evaluateJavascript(
      source: 'setPdfZoom(${zoom.toStringAsFixed(2)});',
    );
  }

  Future<int> findText(String query) async {
    final c = _controller;
    if (c == null) return 0;
    final result = await c.evaluateJavascript(
      source: 'findInPdf(${jsonEncode(query)});',
    );
    if (result is int) return result;
    if (result is num) return result.toInt();
    return 0;
  }
}
