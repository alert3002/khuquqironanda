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

class BookReaderScreen extends StatefulWidget {
  final Book book;
  final int? initialChapterId;

  const BookReaderScreen({
    super.key,
    required this.book,
    this.initialChapterId,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  late List<PageContent> _pages;
  late List<PageContent> _originalPages;
  int _currentPage = 0;
  List<int> _searchResults = [];
  String _searchQuery = ''; // Track search query for highlighting
  List<SearchResultSegment> _searchSegments = []; // Filtered segments when searching
  double _currentFontSize = 13.0; // Font size state variable
  Map<String, String> _authHeaders = {};

  @override
  void initState() {
    super.initState();
    _loadAuthHeaders();
    if (widget.initialChapterId != null) {
      _originalPages = _prepareSingleChapter(widget.initialChapterId!);
    } else {
      final firstChapter = widget.book.chapters.first;
      _originalPages = _prepareSingleChapter(firstChapter.id);
    }
    _pages = _originalPages;
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
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<PageContent> _prepareSingleChapter(int chapterId) {
    final chapter = widget.book.chapters.firstWhere(
      (ch) => ch.id == chapterId,
      orElse: () => widget.book.chapters.first,
    );
    if (!chapter.isFree && !chapter.isPurchased && !widget.book.isPurchased) {
      return [PageContent(chapter.title, '<p style="text-align:center; color:red;">Ин боб пулакӣ аст. Лутфан китобро харид кунед.</p>', chapterId)];
    }
    return _splitIntoPages(chapter.content, chapter.title, chapter.id);
  }

  List<PageContent> _splitIntoPages(String htmlContent, String chapterTitle, int chapterId) {
    final normalizedContent = htmlContent
        // Treat double <br> (with optional spaces) as page breaks
        .replaceAll(
          RegExp(r'(<br\s*/?>\s*){2,}', caseSensitive: false),
          '\n<!--PAGEBREAK-->\n',
        )
        // Treat empty paragraphs from TinyMCE as page breaks
        .replaceAll(
          RegExp(
            r'(<p[^>]*>\s*(?:&nbsp;|\s|<br\s*/?>)*\s*</p>\s*){1,}',
            caseSensitive: false,
          ),
          '\n<!--PAGEBREAK-->\n',
        );

    if (normalizedContent.contains('<!--PAGEBREAK-->')) {
      final parts = normalizedContent.split(
        RegExp(r'<!--PAGEBREAK-->', caseSensitive: false),
      );
      final result = <PageContent>[];
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        result.addAll(_splitIntoPagesWithoutHardBreak(trimmed, chapterTitle, chapterId));
      }
      return result.isEmpty
          ? [PageContent(chapterTitle, '', chapterId)]
          : result;
    }

    return _splitIntoPagesWithoutHardBreak(normalizedContent, chapterTitle, chapterId);
  }

  List<PageContent> _splitIntoPagesWithoutHardBreak(
    String htmlContent,
    String chapterTitle,
    int chapterId,
  ) {
    final pages = <PageContent>[];
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    if (body == null) return [PageContent(chapterTitle, '', chapterId)];

    final elements = body.nodes.whereType<html_dom.Element>().toList();
    String currentPageHtml = '';
    int currentPageLength = 0;
    const int maxPageLength = 900;

    for (final element in elements) {
      final elementHtml = element.outerHtml;
      final elementLength = element.text.length;

      if (element.localName == 'table' || element.querySelectorAll('table').isNotEmpty) {
        if (currentPageHtml.isNotEmpty) {
          pages.add(PageContent(chapterTitle, currentPageHtml, chapterId));
          currentPageHtml = '';
          currentPageLength = 0;
        }
        pages.add(PageContent(chapterTitle, elementHtml, chapterId));
        continue;
      }

      if (currentPageLength + elementLength > maxPageLength && currentPageLength > 0) {
        pages.add(PageContent(chapterTitle, currentPageHtml, chapterId));
        currentPageHtml = '';
        currentPageLength = 0;
      }
      currentPageHtml += elementHtml;
      currentPageLength += elementLength;
    }

    if (currentPageHtml.trim().isNotEmpty) {
      pages.add(PageContent(chapterTitle, currentPageHtml, chapterId));
    }
    return pages;
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.trim();
      _searchSegments.clear();
      _searchResults.clear();
      
      if (_searchQuery.isEmpty) {
        return; // Show normal pages
      }
      
      // Filter-as-you-type: Extract matching segments from all pages
      final queryLower = _searchQuery.toLowerCase();
      
      for (int pageIndex = 0; pageIndex < _originalPages.length; pageIndex++) {
        final page = _originalPages[pageIndex];
        // Strip HTML tags to get plain text
        final plainText = page.content.replaceAll(RegExp(r'<[^>]*>'), '');
        final textLower = plainText.toLowerCase();
        
        if (!textLower.contains(queryLower)) {
          continue; // Skip pages without matches
        }
        
        // Split text into sentences/paragraphs
        // Split by sentence endings (. ! ?) or paragraph breaks
        final segments = plainText.split(RegExp(r'[.!?]\s+|[\n\r]+'));
        
        for (final segment in segments) {
          final segmentLower = segment.trim().toLowerCase();
          if (segmentLower.contains(queryLower) && segment.trim().isNotEmpty) {
            // Found a matching segment
            _searchSegments.add(SearchResultSegment(
              text: segment.trim(),
              chapterTitle: page.chapterTitle,
              pageIndex: pageIndex,
            ));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2d2d2d),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2d2d2d),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: _pages.isNotEmpty
            ? Text(
                _pages[_currentPage].chapterTitle,
                maxLines: 2,
                softWrap: true,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        actions: [
          // Font size decrease button
          IconButton(
            icon: const Icon(Icons.remove, color: Colors.white),
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
            icon: const Icon(Icons.add, color: Colors.white),
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
          // Search Input Field - always visible under AppBar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Ҷустуҷӯ...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                fillColor: Colors.white10,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
              onChanged: _performSearch,
            ),
          ),
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults()
                : PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.horizontal,
                    reverse: false,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPage(_pages[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(PageContent page, int index) {
    return Container(
      // ТАҒЙИРОТ: Кам кардани масофа аз гирди саҳифа (margin) ба 6
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      // ТАҒЙИРОТ: Масофаи дарунии матн (padding) ба 10
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFfafafa),
        borderRadius: BorderRadius.circular(8), // Каме кам кардани радиус барои намуди саҳифа
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5)],
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _searchQuery.isNotEmpty && _searchResults.contains(index)
                  ? _buildHighlightedContent(page.content, _searchQuery)
                  : HtmlWidget(
                      _wrapTablesInScrollableDivs(page.content),
                      textStyle: TextStyle(
                        fontSize: _currentFontSize, // Link font size to state variable
                        height: 1.15, // Line height remains consistent
                        color: Colors.black87,
                      ),
                      customStylesBuilder: _buildHtmlStyles,
                      customWidgetBuilder: _buildHtmlWidget,
                      onTapUrl: (url) => _handleUrlTap(url),
                    ),
            ),
          ),
          const SizedBox(height: 5),
          if (index == _pages.length - 1)
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              ),
              child: const Text("Анҷом", style: TextStyle(color: Colors.white, fontSize: 12)),
            )
          else
            Text("${index + 1} / ${_pages.length}", style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  String _wrapTablesInScrollableDivs(String html) {
    if (!html.contains('<table')) return html;
    final document = html_parser.parse(html);
    for (var table in document.querySelectorAll('table')) {
      final wrapper = document.createElement('div');
      wrapper.attributes['style'] = 'overflow-x: auto; width: 100%; border: 1px solid #ccc;';
      table.replaceWith(wrapper);
      wrapper.append(table);
    }
    return document.body?.innerHtml ?? html;
  }

  Map<String, String> _buildHtmlStyles(html_dom.Element element) {
    final styles = <String, String>{
      'font-size': '${_currentFontSize}px',
      'line-height': '1.15',
    };

    if (element.localName == 'table') {
      styles.addAll({
        'border': '1px solid black',
        'border-collapse': 'collapse',
        'width': '100%',
      });
    }
    if (element.localName == 'td' || element.localName == 'th') {
      styles.addAll({'border': '1px solid black', 'padding': '5px'});
    }

    return styles;
  }

  Widget? _buildHtmlWidget(html_dom.Element element) {
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

  // Build search results list view
  Widget _buildSearchResults() {
    if (_searchSegments.isEmpty) {
      // No matches found
      return Center(
        child: Text(
          "Ҳеҷ чиз ёфт нашуд",
          style: TextStyle(
            fontSize: _currentFontSize,
            color: Colors.white70,
          ),
        ),
      );
    }
    
    // Show all matching segments in a scrollable list
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _searchSegments.length,
      itemBuilder: (context, index) {
        final segment = _searchSegments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFfafafa),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 3)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chapter title indicator
              Text(
                segment.chapterTitle,
                style: TextStyle(
                  fontSize: _currentFontSize - 2,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              // Highlighted segment text
              _buildHighlightedSegment(segment.text, _searchQuery),
            ],
          ),
        );
      },
    );
  }

  // Build highlighted segment with yellow background on search term
  Widget _buildHighlightedSegment(String text, String query) {
    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    
    if (!textLower.contains(queryLower)) {
      return Text(
        text,
        style: TextStyle(
          fontSize: _currentFontSize,
          height: 1.15,
          color: Colors.black87,
        ),
      );
    }
    
    // Find all matches
    final pattern = RegExp(RegExp.escape(queryLower), caseSensitive: false);
    final matches = pattern.allMatches(textLower).toList();
    
    final spans = <TextSpan>[];
    int lastIndex = 0;
    
    for (final match in matches) {
      // Add text before match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(
            fontSize: _currentFontSize,
            height: 1.15,
            color: Colors.black87,
          ),
        ));
      }
      
      // Add highlighted match with yellow background
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          fontSize: _currentFontSize,
          height: 1.15,
          color: Colors.black87,
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          fontSize: _currentFontSize,
          height: 1.15,
          color: Colors.black87,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.justify,
    );
  }

  // Build content with search highlighting (legacy method, kept for compatibility)
  Widget _buildHighlightedContent(String htmlContent, String query) {
    // Strip HTML tags to get plain text for highlighting
    final plainText = htmlContent.replaceAll(RegExp(r'<[^>]*>'), '');
    final queryLower = query.toLowerCase();
    final textLower = plainText.toLowerCase();
    
    if (!textLower.contains(queryLower)) {
      // No match found, return regular HtmlWidget
      return HtmlWidget(
        _wrapTablesInScrollableDivs(htmlContent),
        textStyle: TextStyle(
          fontSize: _currentFontSize,
          height: 1.15,
          color: Colors.black87,
        ),
        customStylesBuilder: _buildHtmlStyles,
      );
    }

    // Find all matches
    final matches = <Match>[];
    final pattern = RegExp(RegExp.escape(queryLower), caseSensitive: false);
    pattern.allMatches(textLower).forEach((match) {
      matches.add(match);
    });

    // Build TextSpans with highlighting
    final spans = <TextSpan>[];
    int lastIndex = 0;
    
    for (final match in matches) {
      // Add text before match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: plainText.substring(lastIndex, match.start),
          style: TextStyle(
            fontSize: _currentFontSize,
            height: 1.15,
            color: Colors.black87,
          ),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: plainText.substring(match.start, match.end),
        style: TextStyle(
          fontSize: _currentFontSize,
          height: 1.15,
          color: Colors.black87,
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < plainText.length) {
      spans.add(TextSpan(
        text: plainText.substring(lastIndex),
        style: TextStyle(
          fontSize: _currentFontSize,
          height: 1.15,
          color: Colors.black87,
        ),
      ));
    }

    // For HTML content with tables, we need to render HTML but highlight text
    // Use HtmlWidget for structure, but we'll show highlighted plain text for search
    // This is a simplified approach - for full HTML highlighting, would need more complex parsing
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.justify,
    );
  }
}

class PageContent {
  final String chapterTitle;
  final String content;
  final int? chapterId;
  PageContent(this.chapterTitle, this.content, this.chapterId);
}

// Class for search result segments
class SearchResultSegment {
  final String text;
  final String chapterTitle;
  final int pageIndex;
  
  SearchResultSegment({
    required this.text,
    required this.chapterTitle,
    required this.pageIndex,
  });
}