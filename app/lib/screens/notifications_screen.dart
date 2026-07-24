import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../api/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _readIdsKey = 'push_read_ids';

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  Set<int> _readIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Set<int> _loadReadIds() {
    try {
      final raw = Hive.box('settings').get(_readIdsKey);
      if (raw is List) {
        return raw.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toSet();
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveReadIds(Set<int> ids) async {
    try {
      await Hive.box('settings').put(_readIdsKey, ids.toList());
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _readIds = _loadReadIds();
    final result = await ApiService.fetchNotifications();
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = result['error']?.toString() ?? 'Хатогӣ';
      });
      return;
    }
    final list = (result['results'] as List?) ?? [];
    setState(() {
      _items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    final ids = _items
        .map((e) => int.tryParse('${e['id']}') ?? 0)
        .where((e) => e > 0)
        .toSet();
    _readIds = {..._readIds, ...ids};
    await _saveReadIds(_readIds);
    if (mounted) setState(() {});
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id']}') ?? 0;
    if (id > 0 && !_readIds.contains(id)) {
      _readIds = {..._readIds, id};
      await _saveReadIds(_readIds);
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item['title']?.toString() ?? 'Огоҳӣ'),
        content: SingleChildScrollView(
          child: Text(item['body']?.toString() ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Пӯшидан'),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return DateFormat('dd.MM.yyyy HH:mm').format(dt);
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Огоҳиҳо'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Ҳамаро хондам'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Аз нав')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('Огоҳӣ нест'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final id = int.tryParse('${item['id']}') ?? 0;
                          final unread = id > 0 && !_readIds.contains(id);
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => _openItem(item),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      unread
                                          ? Icons.notifications_active_rounded
                                          : Icons.notifications_none_rounded,
                                      color: unread
                                          ? const Color(0xFF0D47A1)
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title']?.toString() ?? '',
                                            style: TextStyle(
                                              fontWeight: unread
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['body']?.toString() ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatDate(
                                              item['sent_at'] ??
                                                  item['created_at'],
                                            ),
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (unread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE53935),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// Unread count for home badge (Hive + API).
Future<int> countUnreadNotifications() async {
  final result = await ApiService.fetchNotifications();
  if (result['success'] != true) return 0;
  final list = (result['results'] as List?) ?? [];
  Set<int> readIds = {};
  try {
    final raw = Hive.box('settings').get('push_read_ids');
    if (raw is List) {
      readIds = raw.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toSet();
    }
  } catch (_) {}
  var unread = 0;
  for (final e in list) {
    final id = int.tryParse('${(e as Map)['id']}') ?? 0;
    if (id > 0 && !readIds.contains(id)) unread++;
  }
  return unread;
}
