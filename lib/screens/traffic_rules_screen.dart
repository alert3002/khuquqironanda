import 'package:flutter/material.dart';
import '../data/traffic_rules_data.dart';
import 'legal_documents_list_screen.dart';

/// Бахши «Қоидаҳои ҳаракат дар роҳ».
class TrafficRulesScreen extends StatefulWidget {
  const TrafficRulesScreen({super.key});

  @override
  State<TrafficRulesScreen> createState() => _TrafficRulesScreenState();
}

class _TrafficRulesScreenState extends State<TrafficRulesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrafficRulesMenuItem> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return trafficRulesMenuItems;
    return trafficRulesMenuItems
        .where(
          (m) =>
              m.title.toLowerCase().contains(q) ||
              (m.subtitle?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  void _onMenuTap(TrafficRulesMenuItem item) {
    switch (item.id) {
      case 'legal_acts_list':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LegalDocumentsListScreen(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Қоидаҳои ҳаракат дар роҳ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Ҷустуҷӯ',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF0D47A1),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => _onMenuTap(item),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.article_outlined,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A237E),
                                    height: 1.35,
                                  ),
                                ),
                                if (item.subtitle != null &&
                                    item.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
