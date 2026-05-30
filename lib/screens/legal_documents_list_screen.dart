import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../data/traffic_rules_data.dart' as fallback;
import '../models/legal_document_model.dart';
import '../services/legal_documents_cache.dart';
import 'document_pdf_screen.dart';

/// Рӯйхати санадҳои меъёрию ҳуқуқӣ — аз админка (API).
class LegalDocumentsListScreen extends StatefulWidget {
  const LegalDocumentsListScreen({super.key});

  @override
  State<LegalDocumentsListScreen> createState() =>
      _LegalDocumentsListScreenState();
}

class _LegalDocumentsListScreenState extends State<LegalDocumentsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  double _textScale = 1.0;

  late Future<LegalDocumentsPageData> _pageFuture;
  bool _loadedFromCache = false;

  @override
  void initState() {
    super.initState();
    _pageFuture = _loadPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<LegalDocumentsPageData> _loadPage() async {
    final online = await LegalDocumentsCache.hasNetwork;
    final fromApi = await ApiService.fetchLegalDocuments();
    if (fromApi != null && fromApi.documents.isNotEmpty) {
      if (mounted) {
        setState(() => _loadedFromCache = !online);
      }
      return fromApi;
    }

    final cached = await LegalDocumentsCache.loadPage();
    if (cached != null && cached.documents.isNotEmpty) {
      if (mounted) setState(() => _loadedFromCache = true);
      return cached;
    }

    return _fallbackFromLocal();
  }

  LegalDocumentsPageData _fallbackFromLocal() {
    return LegalDocumentsPageData(
      title: 'Рӯйхати санадҳои меъёрию ҳуқуқии дар китоб истифода шуда',
      intro: fallback.legalActsListIntro,
      documents: fallback.legalDocumentsList
          .map(
            (d) => LegalDocumentModel(
              id: d.number,
              order: d.number,
              title: d.title,
              pdfUrl: d.remoteUrl,
              assetPath: d.assetPath,
              hasPdf: d.hasPdf,
            ),
          )
          .toList(),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _pageFuture = _loadPage();
    });
    await _pageFuture;
  }

  List<LegalDocumentModel> _filter(List<LegalDocumentModel> docs) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return docs;
    return docs.where((d) => d.title.toLowerCase().contains(q)).toList();
  }

  void _openDocument(LegalDocumentModel doc) {
    final remote = LegalDocumentsCache.normalizePdfUrl(doc.pdfUrl);
    final hasRemote = remote != null && remote.isNotEmpty;
    final hasAsset = doc.assetPath != null && doc.assetPath!.isNotEmpty;
    if (!doc.hasPdf || (!hasRemote && !hasAsset)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Барои ин сатр PDF ё ссылка дар админка сабт нашудааст.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentPdfScreen(
          title: doc.title,
          documentId: doc.id,
          remoteUrl: hasRemote ? remote : null,
          assetPath: (!hasRemote && hasAsset) ? doc.assetPath : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: FutureBuilder<LegalDocumentsPageData>(
          future: _pageFuture,
          builder: (context, snapshot) {
            final title = snapshot.data?.title ??
                'Рӯйхати санадҳои меъёрию ҳуқуқии дар китоб истифода шуда';
            return Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            );
          },
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _textScale > 0.85
                ? () => setState(() => _textScale -= 0.1)
                : null,
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            onPressed: _textScale < 1.5
                ? () => setState(() => _textScale += 0.1)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<LegalDocumentsPageData>(
        future: _pageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildMessage(
              'Хатогӣ дар боркунии рӯйхат.',
              showRetry: true,
            );
          }

          final page = snapshot.data;
          if (page == null || page.documents.isEmpty) {
            return _buildMessage(
              'Рӯйхат холӣ аст.\nДар админка → «Санадҳои меъёрию ҳуқуқӣ» сатрҳо илова кунед.',
              showRetry: true,
            );
          }

          final items = _filter(page.documents);
          return Column(
            children: [
              if (_loadedFromCache)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Реҷими офлайн — маълумоти захирашуда',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                    textAlign: TextAlign.center,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Ҷустуҷӯ...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'Ҷустуҷӯ натиҷа надод',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            if (page.intro.isNotEmpty)
                              Text(
                                page.intro,
                                style: TextStyle(
                                  fontSize: 14 * _textScale,
                                  height: 1.45,
                                  color: const Color(0xFF37474F),
                                ),
                              ),
                            const SizedBox(height: 16),
                            ...items.map(_buildListItem),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessage(String text, {bool showRetry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            if (showRetry) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _reload,
                child: const Text('Такрор кардан'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(LegalDocumentModel doc) {
    final remote = LegalDocumentsCache.normalizePdfUrl(doc.pdfUrl);
    final isLink = doc.hasPdf &&
        ((remote != null && remote.isNotEmpty) ||
            (doc.assetPath != null && doc.assetPath!.isNotEmpty));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: isLink ? () => _openDocument(doc) : null,
        borderRadius: BorderRadius.circular(4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${doc.order}. ',
              style: TextStyle(
                fontSize: 14 * _textScale,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A237E),
              ),
            ),
            Expanded(
              child: Text(
                doc.title,
                style: TextStyle(
                  fontSize: 14 * _textScale,
                  height: 1.45,
                  color: isLink
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF37474F),
                  decoration:
                      isLink ? TextDecoration.underline : TextDecoration.none,
                  decorationColor: const Color(0xFF1565C0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
