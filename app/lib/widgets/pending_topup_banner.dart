import 'package:flutter/material.dart';

import '../services/pending_topup_watcher.dart';

class PendingTopUpBanner extends StatelessWidget {
  final PendingTopUpWatcher watcher;
  final EdgeInsetsGeometry padding;

  const PendingTopUpBanner({
    super.key,
    required this.watcher,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final message = watcher.statusMessage;
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (watcher.isWatching)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange.shade800,
                    ),
                  ),
                )
              else
                Icon(Icons.schedule, color: Colors.orange.shade800, size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade900,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
