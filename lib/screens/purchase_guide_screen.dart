import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../api/api_service.dart';
import '../models/book_model.dart';
import '../models/subscription_plan_model.dart';

/// Дастурамали харид + тарифҳо аз админ (AboutPage + SubscriptionPlan).
class PurchaseGuideScreen extends StatefulWidget {
  final Book? book;
  final VoidCallback? onSubscribe;

  const PurchaseGuideScreen({
    super.key,
    this.book,
    this.onSubscribe,
  });

  @override
  State<PurchaseGuideScreen> createState() => _PurchaseGuideScreenState();
}

class _PurchaseGuideScreenState extends State<PurchaseGuideScreen> {
  Map<String, dynamic>? _about;
  Book? _book;
  bool _loading = true;

  static const String _defaultGuideHtml = '''
<ol>
<li>Ба барнома <b>ворид шавед</b> (телефон ё Telegram).</li>
<li>Ба <b>Профил</b> гузаред ва балансро пур кунед.</li>
<li>Тарифи мувофиқро интихоб кунед ва обуна гиред.</li>
<li>Пас аз обуна бобҳои пулакӣ кушода мешаванд.</li>
</ol>
''';

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _load();
  }

  Future<void> _load() async {
    final about = await ApiService.fetchAboutPage();
    Book? book = _book;
    if (book == null || book.plans.isEmpty) {
      book = await ApiService.fetchTargetBook();
    }
    if (!mounted) return;
    setState(() {
      _about = about;
      _book = book;
      _loading = false;
    });
  }

  List<SubscriptionPlan> get _activePlans {
    final plans = _book?.plans ?? [];
    return plans.where((p) => p.isActive).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
  }

  @override
  Widget build(BuildContext context) {
    final title = _about?['purchase_guide_title']?.toString().trim();
    final content = _about?['purchase_guide_content']?.toString().trim() ?? '';
    final guideTitle = (title != null && title.isNotEmpty)
        ? title
        : 'Чӣ тавр харидан мумкин аст';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(guideTitle, style: const TextStyle(fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.help_outline_rounded,
                                  color: Color(0xFF0D47A1)),
                              SizedBox(width: 8),
                              Text(
                                'Дастурамал',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          HtmlWidget(
                            content.isNotEmpty ? content : _defaultGuideHtml,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Тарифҳо',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Нархҳо аз админ (Нақшаҳои обуна)',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    if (_activePlans.isEmpty)
                      _sectionCard(
                        child: const Text(
                          'Тарифҳо ҳанӯз таъин нашудаанд. Лутфан ба админ муроҷиат кунед.',
                          style: TextStyle(fontSize: 14, height: 1.4),
                        ),
                      )
                    else
                      ..._activePlans.map(_planTile),
                    if (widget.onSubscribe != null && _activePlans.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: widget.onSubscribe,
                          icon: const Icon(Icons.card_membership),
                          label: const Text(
                            'Обуна гиред',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _planTile(SubscriptionPlan plan) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _sectionCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF0D47A1).withOpacity(0.12),
              child: const Icon(Icons.star_rounded, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.formattedDuration} · ${plan.formattedPrice}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
