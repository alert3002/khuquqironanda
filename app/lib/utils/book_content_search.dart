import 'package:html/parser.dart' as html_parser;

import '../models/book_model.dart';

/// Як натиҷаи ҷустуҷӯ дар матни боб (аз база / HTML).
class ContentSearchHit {
  final int chapterId;
  final String chapterTitle;
  final int chapterOrder;
  final String snippet;
  final String query;
  final int matchIndex;
  /// Агар боб харида / кушода нашуда бошад — snippet хира нишон дода мешавад.
  final bool isLocked;

  const ContentSearchHit({
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterOrder,
    required this.snippet,
    required this.query,
    required this.matchIndex,
    this.isLocked = false,
  });
}

class BookContentSearch {
  BookContentSearch._();

  /// Матни оддии HTML (тегҳоро тоза мекунад).
  static String stripHtml(String html) {
    if (html.trim().isEmpty) return '';
    try {
      final doc = html_parser.parse(html);
      final text = doc.body?.text ?? html_parser.parseFragment(html).text ?? '';
      return text
          .replaceAll(RegExp(r'\u00a0'), ' ')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    } catch (_) {
      return html
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }
  }

  /// Параграфҳо / блокҳои матн аз HTML.
  static List<String> extractBlocks(String html) {
    if (html.trim().isEmpty) return const [];
    try {
      final doc = html_parser.parse(html);
      final body = doc.body;
      if (body == null) return _fallbackSplit(stripHtml(html));

      final blocks = <String>[];
      final seen = <String>{};

      void addBlock(String? raw) {
        final text = (raw ?? '')
            .replaceAll(RegExp(r'\u00a0'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (text.length < 8) return;
        final key = text.toLowerCase();
        if (seen.contains(key)) return;
        seen.add(key);
        blocks.add(text);
      }

      for (final el in body.querySelectorAll(
        'p, li, h1, h2, h3, h4, h5, h6, td, blockquote',
      )) {
        addBlock(el.text);
      }

      if (blocks.isEmpty) {
        return _fallbackSplit(stripHtml(html));
      }
      return blocks;
    } catch (_) {
      return _fallbackSplit(stripHtml(html));
    }
  }

  static List<String> _fallbackSplit(String plain) {
    if (plain.isEmpty) return const [];
    return plain
        .split(RegExp(r'[\n\r]+|(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 8)
        .toList();
  }

  /// Сниппет бо матн атрофи калимаи ҷустуҷӯ.
  static String makeSnippet(String text, String query, {int radius = 90}) {
    final q = query.trim();
    if (q.isEmpty || text.isEmpty) {
      return text.length <= 180 ? text : '${text.substring(0, 180)}…';
    }
    final lower = text.toLowerCase();
    final qLower = q.toLowerCase();
    final i = lower.indexOf(qLower);
    if (i < 0) {
      return text.length <= 180 ? text : '${text.substring(0, 180)}…';
    }
    final start = i - radius < 0 ? 0 : i - radius;
    final end = (i + q.length + radius > text.length)
        ? text.length
        : i + q.length + radius;
    var snippet = text.substring(start, end).trim();
    if (start > 0) snippet = '…$snippet';
    if (end < text.length) snippet = '$snippet…';
    return snippet;
  }

  /// Ҷустуҷӯ дар ҳамаи бобҳои китоб (матни аз база омада).
  static List<ContentSearchHit> searchBook(
    Book book,
    String query, {
    int maxHits = 80,
  }) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final qLower = q.toLowerCase();
    final hits = <ContentSearchHit>[];

    final chapters = List<Chapter>.from(book.chapters)
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final chapter in chapters) {
      final locked = !(chapter.isFree ||
          chapter.isPurchased ||
          book.isPurchased);

      // Унвон
      if (chapter.title.toLowerCase().contains(qLower)) {
        hits.add(
          ContentSearchHit(
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            chapterOrder: chapter.order,
            snippet: chapter.title,
            query: q,
            matchIndex: hits.length,
            isLocked: locked,
          ),
        );
        if (hits.length >= maxHits) return hits;
      }

      final blocks = extractBlocks(chapter.content);
      if (blocks.isEmpty) {
        final plain = stripHtml(chapter.content);
        if (plain.toLowerCase().contains(qLower)) {
          hits.add(
            ContentSearchHit(
              chapterId: chapter.id,
              chapterTitle: chapter.title,
              chapterOrder: chapter.order,
              snippet: makeSnippet(plain, q),
              query: q,
              matchIndex: hits.length,
              isLocked: locked,
            ),
          );
          if (hits.length >= maxHits) return hits;
        }
        continue;
      }

      for (final block in blocks) {
        if (!block.toLowerCase().contains(qLower)) continue;
        hits.add(
          ContentSearchHit(
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            chapterOrder: chapter.order,
            snippet: makeSnippet(block, q),
            query: q,
            matchIndex: hits.length,
            isLocked: locked,
          ),
        );
        if (hits.length >= maxHits) return hits;
      }
    }

    return hits;
  }
}
