import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/book_content_search.dart';

/// Рӯйхати натиҷаҳои ҷустуҷӯ — кликшаванда, бо highlight-и зард.
class ContentSearchResults extends StatelessWidget {
  final List<ContentSearchHit> hits;
  final String query;
  final ValueChanged<ContentSearchHit> onHitTap;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final String emptyMessage;

  const ContentSearchResults({
    super.key,
    required this.hits,
    required this.query,
    required this.onHitTap,
    this.accentColor = const Color(0xFF0D47A1),
    this.padding = const EdgeInsets.fromLTRB(12, 4, 12, 24),
    this.emptyMessage = 'Ҳеҷ чиз ёфт нашуд',
  });

  @override
  Widget build(BuildContext context) {
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 52, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: hits.length,
      itemBuilder: (context, index) {
        final hit = hits[index];
        return _SearchHitCard(
          hit: hit,
          query: query,
          accentColor: accentColor,
          onTap: () => onHitTap(hit),
        );
      },
    );
  }
}

class _SearchHitCard extends StatelessWidget {
  final ContentSearchHit hit;
  final String query;
  final Color accentColor;
  final VoidCallback onTap;

  const _SearchHitCard({
    required this.hit,
    required this.query,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = hit.isLocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: locked ? const Color(0xFFFFE0B2) : const Color(0xFFE8ECF1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 42,
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    decoration: BoxDecoration(
                      color: locked ? const Color(0xFFFF9800) : accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hit.chapterTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (locked) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: Colors.orange[700],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        _LockedAwareSnippet(
                          text: hit.snippet,
                          query: query,
                          isLocked: locked,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
                    color: locked ? Colors.orange[400] : Colors.grey[400],
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Агар боб кушода набошад — матн blur/хира, вале калимаи ҷустуҷӯ зард мемонад.
class _LockedAwareSnippet extends StatelessWidget {
  final String text;
  final String query;
  final bool isLocked;

  const _LockedAwareSnippet({
    required this.text,
    required this.query,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = HighlightedSearchText(
      text: text,
      query: query,
      locked: isLocked,
      style: const TextStyle(
        fontSize: 14.5,
        height: 1.35,
        color: Color(0xFF1A1A1A),
      ),
    );

    if (!isLocked) return highlighted;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
            child: Opacity(
              opacity: 0.72,
              child: highlighted,
            ),
          ),
          // Калимаҳои мувофиқ болои blur — зард ва хондашаванда
          HighlightedSearchText(
            text: text,
            query: query,
            locked: true,
            matchesOnly: true,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Матн бо зард highlight кардани калимаи ҷустуҷӯ.
class HighlightedSearchText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool locked;
  /// Танҳо калимаҳои мувофиқро нишон диҳ (боқӣ шаффоф) — барои қабати болои blur.
  final bool matchesOnly;

  const HighlightedSearchText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.textAlign = TextAlign.start,
    this.locked = false,
    this.matchesOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle(fontSize: 14.5, color: Colors.black87);
    final q = query.trim();
    if (q.isEmpty) {
      return Text(
        text,
        style: matchesOnly ? base.copyWith(color: Colors.transparent) : base,
        textAlign: textAlign,
      );
    }

    final pattern = RegExp(RegExp.escape(q), caseSensitive: false);
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(
        text,
        style: matchesOnly ? base.copyWith(color: Colors.transparent) : base,
        textAlign: textAlign,
      );
    }

    final spans = <TextSpan>[];
    var last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(
          TextSpan(
            text: text.substring(last, m.start),
            style: matchesOnly
                ? base.copyWith(color: Colors.transparent)
                : base,
          ),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: base.copyWith(
            backgroundColor: const Color(0xFFFFEB3B),
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(last),
          style: matchesOnly
              ? base.copyWith(color: Colors.transparent)
              : base,
        ),
      );
    }

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans),
    );
  }
}
