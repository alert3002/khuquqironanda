import 'dart:convert';

/// HTML-и pdf.js барои [PdfJsViewer] — fit-to-width, zoom бе бенурӣ.
String buildPdfJsShellHtml({
  required String pdfJsLib,
  required String pdfWorker,
  required double initialZoom,
  String? pdfOpenUrl,
}) {
  final lib = pdfJsLib.replaceAll('</script>', r'<\/script>');
  final worker = pdfWorker.replaceAll('</script>', r'<\/script>');
  final userZoom = initialZoom.toStringAsFixed(2);
  final autoUrl = jsonEncode(pdfOpenUrl ?? '');

  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0; padding: 0;
      height: 100%;
      overflow: hidden;
      background: #f5f7fa;
    }
    #viewer-scroll {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      overflow: auto;
      -webkit-overflow-scrolling: touch;
      overscroll-behavior: contain;
    }
    #pan-hint {
      display: none;
      position: sticky;
      top: 0;
      z-index: 10;
      background: #e3f2fd;
      color: #1565c0;
      text-align: center;
      padding: 8px 12px;
      font-family: sans-serif;
      font-size: 12px;
      border-bottom: 1px solid #bbdefb;
    }
    #pages {
      padding: 8px 6px 24px 6px;
      width: max-content;
      max-width: none;
      margin: 0 auto;
    }
    canvas {
      display: block;
      margin: 0 auto 14px auto;
      box-shadow: 0 2px 8px rgba(0,0,0,0.12);
      background: white;
    }
    #status {
      text-align: center;
      padding: 24px;
      color: #555;
      font-family: sans-serif;
      font-size: 14px;
    }
    .hit { outline: 2px solid #ff9800; }
  </style>
</head>
<body>
  <div id="viewer-scroll">
    <div id="pan-hint">← → Барои хондан тарафи рост — экранро ба чап/рост кашед</div>
    <div id="status">Боркунӣ...</div>
    <div id="pages"></div>
  </div>
  <script>$lib</script>
  <script>
    (function() {
      const workerCode = ${jsonEncode(worker)};
      const blob = new Blob([workerCode], { type: 'application/javascript' });
      pdfjsLib.GlobalWorkerOptions.workerSrc = URL.createObjectURL(blob);

      let pdfDoc = null;
      let userZoom = $userZoom;
      let lastFindCount = 0;

      function setStatus(msg) {
        const el = document.getElementById('status');
        if (el) {
          el.style.display = 'block';
          el.textContent = msg;
        }
      }

      function hideStatus() {
        const el = document.getElementById('status');
        if (el) el.style.display = 'none';
      }

      function updatePanHint() {
        const hint = document.getElementById('pan-hint');
        if (hint) hint.style.display = userZoom > 1.02 ? 'block' : 'none';
      }

      function containerWidth() {
        const el = document.getElementById('viewer-scroll');
        return Math.max((el ? el.clientWidth : window.innerWidth) - 12, 240);
      }

      function calcFitScale(page) {
        const vp = page.getViewport({ scale: 1.0 });
        return containerWidth() / vp.width;
      }

      async function renderPage(n, container) {
        const page = await pdfDoc.getPage(n);
        const fit = calcFitScale(page);
        const renderScale = fit * userZoom;
        const dpr = window.devicePixelRatio || 1;
        const viewport = page.getViewport({ scale: renderScale });

        const canvas = document.createElement('canvas');
        canvas.dataset.page = String(n);
        const ctx = canvas.getContext('2d');
        canvas.width = Math.floor(viewport.width * dpr);
        canvas.height = Math.floor(viewport.height * dpr);
        canvas.style.width = Math.floor(viewport.width) + 'px';
        canvas.style.height = Math.floor(viewport.height) + 'px';
        if (userZoom > 1.02) {
          canvas.style.margin = '0 0 14px 0';
        } else {
          canvas.style.margin = '0 auto 14px auto';
        }
        container.appendChild(canvas);

        const transform = dpr !== 1 ? [dpr, 0, 0, dpr, 0, 0] : null;
        await page.render({
          canvasContext: ctx,
          viewport: viewport,
          transform: transform,
        }).promise;
      }

      async function renderAll() {
        const container = document.getElementById('pages');
        if (!container || !pdfDoc) return;
        container.innerHTML = '';
        const numPages = pdfDoc.numPages;

        setStatus('Боркунӣ...');
        await renderPage(1, container);
        hideStatus();

        for (let n = 2; n <= numPages; n++) {
          await renderPage(n, container);
          if (n % 2 === 0) {
            await new Promise(function(r) { requestAnimationFrame(r); });
          }
        }
        updatePanHint();
      }

      async function openPdfData(uint8) {
        setStatus('Боркунӣ...');
        pdfDoc = await pdfjsLib.getDocument({ data: uint8 }).promise;
        await renderAll();
      }

      window.loadPdfFromUrl = async function(url) {
        try {
          setStatus('Боркунӣ...');
          pdfDoc = await pdfjsLib.getDocument({ url: url }).promise;
          await renderAll();
        } catch (e) {
          setStatus('Хатогӣ: ' + e);
        }
      };

      window.setPdfZoom = async function(z) {
        userZoom = Math.max(0.75, Math.min(2.5, Number(z) || 1));
        updatePanHint();
        if (pdfDoc) await renderAll();
      };

      window.findInPdf = async function(query) {
        if (!pdfDoc || !query) {
          lastFindCount = 0;
          return 0;
        }
        const q = String(query).trim().toLowerCase();
        if (!q) {
          lastFindCount = 0;
          return 0;
        }
        let hits = 0;
        document.querySelectorAll('.hit').forEach(function(el) {
          el.classList.remove('hit');
        });
        for (let n = 1; n <= pdfDoc.numPages; n++) {
          const page = await pdfDoc.getPage(n);
          const tc = await page.getTextContent();
          const text = tc.items.map(function(it) { return it.str || ''; }).join(' ').toLowerCase();
          if (text.includes(q)) {
            hits++;
            const canvas = document.querySelector('canvas[data-page="' + n + '"]');
            if (canvas) canvas.classList.add('hit');
          }
        }
        lastFindCount = hits;
        return hits;
      };

      window.addEventListener('resize', function() {
        if (pdfDoc) renderAll();
      });

      const autoUrl = $autoUrl;
      if (autoUrl) {
        window.loadPdfFromUrl(autoUrl);
      }
    })();
  </script>
</body>
</html>
''';
}
