import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// PDF дар Web — pdf.js (без тугмаҳои print/download).
class WebPdfView extends StatefulWidget {
  final String url;

  const WebPdfView({super.key, required this.url});

  @override
  State<WebPdfView> createState() => _WebPdfViewState();
}

class _WebPdfViewState extends State<WebPdfView> {
  late final String _viewType =
      'legal-pdf-${DateTime.now().millisecondsSinceEpoch}';

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final b64 = base64Encode(response.bodyBytes);
      final htmlContent = _buildPdfJsHtml(b64);

      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
          iframe.srcdoc = htmlContent;
          return iframe;
        },
      );

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _buildPdfJsHtml(String b64) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; padding: 0; background: #f5f7fa; }
    #pages { padding: 8px; }
    canvas {
      display: block;
      margin: 0 auto 12px auto;
      max-width: 100%;
      box-shadow: 0 2px 8px rgba(0,0,0,0.15);
      background: white;
    }
    #status { text-align: center; padding: 24px; color: #555; font-family: sans-serif; }
  </style>
</head>
<body>
  <div id="status">Боркунӣ...</div>
  <div id="pages"></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
  <script>
    pdfjsLib.GlobalWorkerOptions.workerSrc =
      'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
    (async function() {
      try {
        const raw = atob('$b64');
        const data = new Uint8Array(raw.length);
        for (let i = 0; i < raw.length; i++) data[i] = raw.charCodeAt(i);
        const pdf = await pdfjsLib.getDocument({ data: data }).promise;
        const container = document.getElementById('pages');
        document.getElementById('status').style.display = 'none';
        for (let n = 1; n <= pdf.numPages; n++) {
          const page = await pdf.getPage(n);
          const viewport = page.getViewport({ scale: 1.35 });
          const canvas = document.createElement('canvas');
          canvas.width = viewport.width;
          canvas.height = viewport.height;
          container.appendChild(canvas);
          await page.render({ canvasContext: canvas.getContext('2d'), viewport: viewport }).promise;
        }
      } catch (e) {
        document.getElementById('status').textContent = 'Хатогӣ: ' + e;
      }
    })();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'PDF кушода нашуд: $_error',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return HtmlElementView(viewType: _viewType);
  }
}
