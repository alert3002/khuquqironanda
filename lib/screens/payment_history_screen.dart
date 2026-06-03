import 'package:flutter/material.dart';
import '../api/api_service.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({bool showSnack = false}) async {
    if (!_isLoading) setState(() => _isRefreshing = true);
    else setState(() => _isLoading = true);

    final sync = await ApiService.syncPendingTopUpsAndBalance();
    final items = sync['history'] is List
        ? List<Map<String, dynamic>>.from(sync['history'] as List)
        : await ApiService.fetchPaymentHistory();

    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
      _isRefreshing = false;
    });

    if (showSnack) {
      final pending = items
          .where((e) => e['status']?.toString() == 'PENDING')
          .length;
      if (pending == 0 && (sync['became_success'] as int? ?? 0) > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пардохтҳо қабул шуданд. Баланс навсозӣ шуд.'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (pending > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ҳанӯз $pending пардохт дар интизорӣ. '
              'Агар пул ситода шуд, чанд дақиқа интизор шавед ва боз «Навсозӣ»-ро пахш кунед.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Навсозӣ шуд')),
        );
      }
    }
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'SUCCESS':
        return 'Қабул шуд';
      case 'FAILED':
        return 'Рад шуд';
      case 'PENDING':
        return 'Дар интизорӣ';
      default:
        return status ?? '-';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'SUCCESS':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'PENDING':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return iso;
    }
  }

  int get _pendingCount =>
      _items.where((e) => e['status']?.toString() == 'PENDING').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Историяи пардохт'),
        actions: [
          IconButton(
            tooltip: 'Навсозӣ',
            onPressed: _isRefreshing ? null : () => _loadHistory(showSnack: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_pendingCount > 0)
                  Material(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_pendingCount пардохт дар интизорӣ. '
                              'Пас аз пардохт дар бонк тугмаи «Навсозӣ»-ро пахш кунед.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _isRefreshing
                                ? null
                                : () => _loadHistory(showSnack: true),
                            child: const Text('Навсозӣ'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('Ҳоло ҳеҷ пардохт нест'))
                      : RefreshIndicator(
                          onRefresh: () => _loadHistory(showSnack: true),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final status = item['status']?.toString();
                              final amount = item['amount']?.toString() ?? '-';
                              final description =
                                  item['description']?.toString() ?? '';
                              final createdAt = item['created_at']?.toString();

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  title: Text(
                                    '$amount сомонӣ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_formatDate(createdAt)}\n'
                                    '${description.isEmpty ? '-' : description}',
                                  ),
                                  trailing: Text(
                                    _formatStatus(status),
                                    style: TextStyle(
                                      color: _statusColor(status),
                                    ),
                                  ),
                                  isThreeLine: true,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
