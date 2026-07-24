import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ёрӣ: агар маблағ ба баланс нагузашт — чек фиристед.
/// Хурд, равшан, барои профил (болои баланс).
class BalanceHelpCard extends StatelessWidget {
  final bool compact;

  const BalanceHelpCard({super.key, this.compact = true});

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 10 : 16,
        compact ? 12 : 16,
        compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Маблағ ба баланс нагузашт?',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Чеки пардохт ва номери худро ба админ фиристед — мо тафтиш мекунем!',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Colors.blueGrey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ContactBtn(
                  label: 'Telegram',
                  color: const Color(0xFF229ED9),
                  iconAsset: 'img/telegram.png',
                  fallback: Icons.send_rounded,
                  onTap: () => _open('https://t.me/group1week'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ContactBtn(
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  iconAsset: 'img/whatsapp.png',
                  fallback: Icons.chat_rounded,
                  onTap: () => _open('https://wa.me/+992987003002'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactBtn extends StatelessWidget {
  final String label;
  final Color color;
  final String iconAsset;
  final IconData fallback;
  final VoidCallback onTap;

  const _ContactBtn({
    required this.label,
    required this.color,
    required this.iconAsset,
    required this.fallback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Image.asset(
                  iconAsset,
                  errorBuilder: (_, __, ___) =>
                      Icon(fallback, size: 16, color: color),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
