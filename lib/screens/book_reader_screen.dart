import 'dart:async';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'dart:io';

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../api/api_service.dart';
import '../models/book_model.dart';
import '../utils/book_content_search.dart';
import '../widgets/content_search_results.dart';

class BookReaderScreen extends StatefulWidget {
  final Book book;
  final int? initialChapterId;
  /// Агар аз саҳифаи асосӣ бо натиҷаи ҷустуҷӯ кушода шавад.
  final String? initialSearchQuery;
  final String? focusSnippet;

  const BookReaderScreen({
    super.key,
    required this.book,
    this.initialChapterId,
    this.initialSearchQuery,
    this.focusSnippet,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _focusBlockKey = GlobalKey();
  late List<PageContent> _pages;
  late List<PageContent> _originalPages;
  String _searchQuery = '';
  List<ContentSearchHit> _searchHits = [];
  /// Вақте натиҷа пахш шуд — матнро бо highlight нишон медиҳем.
  String _highlightQuery = '';
  String? _focusSnippet;
  double _currentFontSize = 13.0;
  Map<String, String> _authHeaders = {};
  Timer? _searchDebounce;
  bool _isPreparingContent = true;
  List<String> _renderChunks = const [];
  List<String> _contentBlocks = const [];

  @override
  void initState() {
    super.initState();
    _loadAuthHeaders();
    unawaited(ApiService.persistBookForOffline(widget.book));
    if (widget.initialChapterId != null) {
      _originalPages = _prepareSingleChapter(widget.initialChapterId!);
    } else {
      final firstChapter = widget.book.chapters.first;
      _originalPages = _prepareSingleChapter(firstChapter.id);
    }
    _pages = _originalPages;
    _prepareRenderChunks();

    final initialQ = widget.initialSearchQuery?.trim() ?? '';
    if (initialQ.isNotEmpty && widget.focusSnippet != null) {
      // Кушодан бо натиҷаи кликшуда — ҳамон матнро нишон диҳ
      _highlightQuery = initialQ;
      _focusSnippet = widget.focusSnippet;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
    } else if (initialQ.isNotEmpty) {
      _searchController.text = initialQ;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(initialQ);
      });
    }
  }

  Future<void> _loadAuthHeaders() async {
    try {
      final headers = await ApiService.getAuthHeaders();
      if (mounted) {
        setState(() {
          _authHeaders = headers;
        });
      }
    } catch (_) {
      // Ignore header load errors
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openSearchHit(ContentSearchHit hit) {
    final chapter = widget.book.chapters.firstWhere(
      (c) => c.id == hit.chapterId,
      orElse: () => widget.book.chapters.first,
    );
    final canRead =
        chapter.isFree || chapter.isPurchased || widget.book.isPurchased;
    if (!canRead) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ин боб пулакӣ аст. Лутфан обуна гиред.'),
        ),
      );
      return;
    }

    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchHits = const [];
      _highlightQuery = hit.query;
      _focusSnippet = hit.snippet;
      _originalPages = _prepareSingleChapter(hit.chapterId);
      _pages = _originalPages;
      _isPreparingContent = true;
      _renderChunks = const [];
      _contentBlocks = const [];
    });
    unawaited(_prepareRenderChunks());
  }

  List<PageContent> _prepareSingleChapter(int chapterId) {
    final chapter = widget.book.chapters.firstWhere(
      (ch) => ch.id == chapterId,
      orElse: () => widget.book.chapters.first,
    );
    if (!chapter.isFree && !chapter.isPurchased && !widget.book.isPurchased) {
      return [PageContent(chapter.title, '<p style="text-align:center; color:red;">Ин боб пулакӣ аст. Лутфан китобро харид кунед.</p>', chapterId)];
    }
    // Show full chapter in one block (no pagination like 1/24, 2/24).
    return [PageContent(chapter.title, chapter.content, chapter.id)];
  }

  Future<void> _prepareRenderChunks() async {
    setState(() {
      _isPreparingContent = true;
      _renderChunks = const [];
      _contentBlocks = const [];
    });
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final html = _pages.first.content;
    final chunks = _splitHtmlIntoRenderChunks(html);
    final blocks = BookContentSearch.extractBlocks(html);
    if (!mounted) return;
    setState(() {
      _renderChunks = chunks;
      _contentBlocks = blocks.isEmpty
          ? [BookContentSearch.stripHtml(html)]
          : blocks;
      _isPreparingContent = false;
    });
    if (_focusSnippet != null && _highlightQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
    }
  }

  void _scrollToFocus() {
    final ctx = _focusBlockKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  List<String> _splitHtmlIntoRenderChunks(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    if (body == null) return [htmlContent];

    final chunks = <String>[];
    final buffer = StringBuffer();
    var textLen = 0;
    const maxChunkLen = 1200;

    for (final node in body.nodes.whereType<html_dom.Element>()) {
      final fragment = node.outerHtml;
      final nodeTextLen = node.text.trim().length;
      final isHeavy = fragment.contains('<table') || fragment.contains('<img');

      if (isHeavy) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString());
          buffer.clear();
          textLen = 0;
        }
        chunks.add(fragment);
        continue;
      }

      if (textLen > 0 && textLen + nodeTextLen > maxChunkLen) {
        chunks.add(buffer.toString());
        buffer.clear();
        textLen = 0;
      }
      buffer.write(fragment);
      textLen += nodeTextLen;
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }
    return chunks.isEmpty ? [htmlContent] : chunks;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) {
        _performSearch(value);
      }
    });
  }

  void _performSearch(String query) {
    final q = query.trim();
    setState(() {
      _searchQuery = q;
      _searchHits = q.isEmpty
          ? const []
          : BookContentSearch.searchBook(widget.book, q);
      // Ҳангоми навиштани ҷустуҷӯ — режими хонданро пӯшон
      if (q.isNotEmpty) {
        _highlightQuery = '';
        _focusSnippet = null;
      }
    });
  }

  void _clearHighlightMode() {
    setState(() {
      _highlightQuery = '';
      _focusSnippet = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: _pages.isNotEmpty
            ? Text(
                _pages.first.chapterTitle,
                maxLines: 2,
                softWrap: true,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        actions: [
          // Font size decrease button
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.black),
            onPressed: () {
              setState(() {
                if (_currentFontSize > 10) {
                  _currentFontSize -= 1.0;
                }
              });
            },
            tooltip: "Кам кардани андозаи ҳарф",
          ),
          // Font size increase button
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              setState(() {
                if (_currentFontSize < 25) {
                  _currentFontSize += 1.0;
                }
              });
            },
            tooltip: "Зиёд кардани андозаи ҳарф",
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Ҷустуҷӯ...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                suffixIcon: _searchQuery.isNotEmpty || _highlightQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.black54),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          _performSearch('');
                          _clearHighlightMode();
                        },
                      )
                    : null,
                fillColor: const Color(0xFFF2F2F2),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_highlightQuery.isNotEmpty && _searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Material(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _clearHighlightMode,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.highlight_rounded, size: 18, color: Color(0xFFF9A825)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Натиҷаи ҷустуҷӯ: «$_highlightQuery»',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
                          ),
                        ),
                        Icon(Icons.close, size: 16, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _searchQuery.isNotEmpty
                ? ContentSearchResults(
                    hits: _searchHits,
                    query: _searchQuery,
                    onHitTap: _openSearchHit,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  )
                : _highlightQuery.isNotEmpty
                    ? (_isPreparingContent
                        ? Center(child: _buildLoadingSkeleton())
                        : _buildHighlightedReadingView())
                    : ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          _buildPage(_pages.first, 0),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedReadingView() {
    final q = _highlightQuery;
    final focusNorm = (_focusSnippet ?? '')
        .replaceAll('…', '')
        .toLowerCase()
        .trim();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
      itemCount: _contentBlocks.length,
      itemBuilder: (context, index) {
        final block = _contentBlocks[index];
        final blockLower = block.toLowerCase();
        final isMatch = q.isNotEmpty && blockLower.contains(q.toLowerCase());
        final isFocus = focusNorm.isNotEmpty &&
            (blockLower.contains(focusNorm) ||
                focusNorm.contains(blockLower) ||
                _snippetsOverlap(blockLower, focusNorm));

        return Container(
          key: isFocus ? _focusBlockKey : null,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isFocus
                ? const Color(0xFFFFF59D)
                : isMatch
                    ? const Color(0xFFFFFDE7)
                    : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFocus
                  ? const Color(0xFFFBC02D)
                  : isMatch
                      ? const Color(0xFFFFECB3)
                      : const Color(0xFFE0E0E0),
              width: isFocus ? 1.5 : 1,
            ),
            boxShadow: isFocus
                ? [
                    BoxShadow(
                      color: const Color(0xFFFBC02D).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: HighlightedSearchText(
            text: block,
            query: q,
            style: TextStyle(
              fontSize: _currentFontSize,
              height: 1.35,
              color: Colors.black87,
            ),
            textAlign: TextAlign.justify,
          ),
        );
      },
    );
  }

  bool _snippetsOverlap(String a, String b) {
    if (a.length < 20 || b.length < 20) return false;
    final short = a.length <= b.length ? a : b;
    final long = a.length > b.length ? a : b;
    final mid = short.length ~/ 2;
    final start = (mid - 18).clamp(0, short.length);
    final end = (mid + 18).clamp(0, short.length);
    final needle = short.substring(start, end);
    return needle.length >= 12 && long.contains(needle);
  }

  Widget _buildPage(PageContent page, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFfafafa),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
      ),
      child: Column(
        children: [
          if (_isPreparingContent)
            _buildLoadingSkeleton()
          else
            ..._renderChunks.map(
              (chunk) => HtmlWidget(
                _prepareHtmlForRender(chunk),
                textStyle: TextStyle(
                  fontSize: _currentFontSize,
                  height: 1.4,
                  color: Colors.black87,
                ),
                customStylesBuilder: _buildHtmlStyles,
                customWidgetBuilder: _buildHtmlWidget,
                onTapUrl: (url) => _handleUrlTap(url),
              ),
            ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(
        4,
        (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: i == 0 ? 24 : 16,
          decoration: BoxDecoration(
            color: const Color(0xFFE9E9E9),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  /// HTML-ро барои Android/iOS омода мекунад (таблицаҳо алоҳида render мешаванд).
  String _prepareHtmlForRender(String html) {
    if (!html.contains('<table')) return html;
    // Таблицаҳоро аз HtmlWidget берун мекунем — customWidgetBuilder онҳоро мекашад.
    // Стилҳои зарарнок (height/line-height-и қатъӣ) дар td-ро тоза мекунем.
    final document = html_parser.parse(html);
    for (final td in document.querySelectorAll('td, th, p, span, div')) {
      final style = td.attributes['style'];
      if (style == null || style.isEmpty) continue;
      var cleaned = style
          .replaceAll(RegExp(r'line-height\s*:\s*[^;]+;?', caseSensitive: false), '')
          .replaceAll(RegExp(r'height\s*:\s*[^;]+;?', caseSensitive: false), '')
          .replaceAll(RegExp(r'min-height\s*:\s*[^;]+;?', caseSensitive: false), '')
          .replaceAll(RegExp(r'max-height\s*:\s*[^;]+;?', caseSensitive: false), '')
          .trim();
      if (cleaned.isEmpty || cleaned == ';') {
        td.attributes.remove('style');
      } else {
        td.attributes['style'] = cleaned;
      }
    }
    return document.body?.innerHtml ?? html;
  }

  Map<String, String> _buildHtmlStyles(html_dom.Element element) {
    final styles = <String, String>{
      'font-size': '${_currentFontSize}px',
      'line-height': '1.4',
    };

    if (element.localName == 'p') {
      styles.addAll({
        'margin': '0 0 8px 0',
        'padding': '0',
      });
    }

    if (element.localName == 'table') {
      styles.addAll({
        'border': '1px solid #222',
        'border-collapse': 'collapse',
        'width': 'auto',
      });
    }
    if (element.localName == 'td' || element.localName == 'th') {
      styles.addAll({
        'border': '1px solid #222',
        'padding': '8px',
        'vertical-align': 'top',
        'line-height': '1.4',
        'white-space': 'normal',
      });
    }

    return styles;
  }

  Widget? _buildHtmlWidget(html_dom.Element element) {
    // Ҷадвал — рендери алоҳида (Android HtmlWidget матнро болои ҳам мекашад)
    if (element.localName == 'table') {
      return _buildNativeHtmlTable(element);
    }

    if (element.localName == 'img') {
      final src = element.attributes['src'];
      if (src == null || src.trim().isEmpty) return null;
      final normalized = _normalizeUrl(src);
      if (normalized == null) return null;
      final style = element.attributes['style'] ?? '';
      final width = _extractSizePx(style, 'width');
      final height = _extractSizePx(style, 'height');

      final baseHost = Uri.parse(ApiService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '')).host;
      final imgHost = Uri.parse(normalized).host;
      final useAuth = _authHeaders.isNotEmpty && imgHost == baseHost;

      final image = SizedBox(
        width: width,
        height: height,
        child: Image.network(
          normalized,
          headers: useAuth ? _authHeaders : null,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
          cacheWidth: width != null ? (width * 2).round() : 1200,
          cacheHeight: height != null ? (height * 2).round() : null,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox.shrink();
          },
        ),
      );

      final parent = element.parent;
      if (parent != null && parent.localName == 'a') {
        final href = parent.attributes['href'];
        if (href != null && href.trim().isNotEmpty) {
          return GestureDetector(
            onTap: () => _handleUrlTap(href),
            child: image,
          );
        }
      }

      return image;
    }
    return null;
  }

  /// Ҷадвали HTML → Flutter Table (як экран, мисли iPhone).
  Widget _buildNativeHtmlTable(html_dom.Element table) {
    final rows = <List<_TableCellData>>[];
    for (final tr in table.querySelectorAll('tr')) {
      final cells = <_TableCellData>[];
      for (final cell in tr.children) {
        if (cell.localName != 'td' && cell.localName != 'th') continue;
        cells.add(
          _TableCellData(
            text: _cellPlainText(cell),
            isHeader: cell.localName == 'th',
          ),
        );
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final colCount = rows.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);

    // Тақсимоти сутунҳо мисли iPhone — ҳама дар як экран
    final columnWidths = <int, TableColumnWidth>{};
    if (colCount == 4) {
      columnWidths[0] = const FlexColumnWidth(1.1); // КҲМ
      columnWidths[1] = const FlexColumnWidth(2.4); // Номгӯ
      columnWidths[2] = const FlexColumnWidth(2.0); // Ҷазо
      columnWidths[3] = const FlexColumnWidth(1.8); // Мақомот
    } else if (colCount == 3) {
      columnWidths[0] = const FlexColumnWidth(1.2);
      columnWidths[1] = const FlexColumnWidth(2.4);
      columnWidths[2] = const FlexColumnWidth(2.0);
    } else if (colCount == 2) {
      columnWidths[0] = const FlexColumnWidth(1.2);
      columnWidths[1] = const FlexColumnWidth(3.0);
    } else {
      for (var i = 0; i < colCount; i++) {
        columnWidths[i] = const FlexColumnWidth(1);
      }
    }

    // Каме хурдтар аз матни асосӣ — то дар як экран ҷой шавад
    final tableFont = (_currentFontSize - 1).clamp(10.0, 16.0);
    final textStyle = TextStyle(
      fontSize: tableFont,
      height: 1.3,
      color: Colors.black87,
    );
    final headerStyle = textStyle.copyWith(fontWeight: FontWeight.w700);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;

        return Container(
          width: maxW,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black87, width: 1),
          ),
          child: Table(
            border: TableBorder.all(color: Colors.black87, width: 1),
            columnWidths: columnWidths,
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              for (final row in rows)
                TableRow(
                  children: [
                    for (var i = 0; i < colCount; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 5,
                        ),
                        child: Text(
                          i < row.length ? row[i].text : '',
                          softWrap: true,
                          style: (i < row.length && row[i].isHeader)
                              ? headerStyle
                              : textStyle,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  String _cellPlainText(html_dom.Element cell) {
    // Матни ҳуҷайра бе тегҳои иловагӣ — overlap-ро дар Android пешгирӣ мекунад
    final text = cell.text
        .replaceAll(RegExp(r'\u00a0'), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();
    return text;
  }

  Future<bool> _handleUrlTap(String url) async {
    try {
      final normalized = _normalizeUrl(url);
      if (normalized == null) return false;

      final uri = Uri.parse(normalized);
      final path = uri.path.toLowerCase();
      final isPdf = path.endsWith('.pdf') || path.contains('.pdf');

      if (isPdf) {
        return await _downloadPdf(uri);
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return launched;
    } catch (_) {
      return false;
    }
  }

  String? _normalizeUrl(String url) {
    if (url.startsWith('javascript:')) return null;
    var normalized = url.trim();
    if (normalized.startsWith('www.')) {
      normalized = 'https://$normalized';
    } else if (normalized.startsWith('/')) {
      final base = ApiService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      normalized = '$base$normalized';
    } else if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      final base = ApiService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      normalized = '$base/$normalized';
    }
    return normalized;
  }

  Future<bool> _downloadPdf(Uri uri) async {
    try {
      final headers = _authHeaders.isNotEmpty
          ? _authHeaders
          : await ApiService.getAuthHeaders();
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Хатогӣ дар боргирии PDF')),
          );
        }
        return false;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Файл холӣ аст')),
          );
        }
        return false;
      }

      Directory dir = await _getPreferredDownloadDirectory();
      var fileName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF захира шуд: ${file.path}')),
        );
      }
      await _openFile(file);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Хатогӣ ҳангоми боргирӣ')),
        );
      }
      return false;
    }
  }

  Future<void> _openFile(File file) async {
    try {
      await launchUrl(
        Uri.file(file.path),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Ignore open errors
    }
  }

  Future<Directory> _getPreferredDownloadDirectory() async {
    if (Platform.isAndroid) {
      await _ensureStoragePermission();
      final candidates = <String>[
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Download',
      ];
      for (final path in candidates) {
        final directory = Directory(path);
        if (await directory.exists()) {
          return directory;
        }
      }
      return await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _ensureStoragePermission() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdk = androidInfo.version.sdkInt;
      if (sdk >= 30) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Барои захира иҷозат (Files) диҳед')),
          );
        }
      } else {
        final status = await Permission.storage.request();
        if (!status.isGranted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Барои захира иҷозат (Storage) диҳед')),
          );
        }
      }
    } catch (_) {
      // Ignore permission errors
    }
  }

  double? _extractSizePx(String style, String key) {
    final match = RegExp('$key\\s*:\\s*(\\d+(?:\\.\\d+)?)px', caseSensitive: false)
        .firstMatch(style);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }
}

class PageContent {
  final String chapterTitle;
  final String content;
  final int? chapterId;
  PageContent(this.chapterTitle, this.content, this.chapterId);
}
class _TableCellData {
  final String text;
  final bool isHeader;
  const _TableCellData({required this.text, required this.isHeader});
}
