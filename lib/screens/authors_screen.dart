import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Экрани «Муаллифон» — ширкатҳо ва муаллифон.
class AuthorsScreen extends StatelessWidget {
  const AuthorsScreen({super.key});

  static const _bg = Color(0xFFF5F7FA);
  static const _primary = Color(0xFF1A237E);
  static const _vakil = Color(0xFF1565C0);
  static const _week = Color(0xFF00897B);

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Link ochish mumkin nest');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Муаллифон',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHeroBanner(),
          const SizedBox(height: 20),
          _buildCompanyCard(
            accent: _vakil,
            icon: Icons.balance_rounded,
            title: 'Ширкати ҳуқуқии «Вакил»',
            body:
                'Барои шаҳрвандон ва ташкилоту корхонаҳо хизматрасониҳои ҳуқуқии касбӣ '
                '(машваратҳои ҳуқуқӣ, омода кардани ҳуҷҷатҳои дохилии ташкилот, '
                'тартиб додани шартномаҳо, намояндагӣ дар суд ва дигар мақомот) '
                'ро пешниҳод мекунад.',
          ),
          const SizedBox(height: 14),
          _buildCompanyCard(
            accent: _week,
            icon: Icons.devices_rounded,
            title: 'IT компания «1week»',
            body:
                'Барои соҳибкорон ва ташкилоту корхонаҳо хизматрасониҳои '
                'сомона (сайт), барномаи мобилӣ ва пешбурди сомонаҳои иҷтимоӣ (SMM) '
                'ро пешниҳод мекунад.',
          ),
          const SizedBox(height: 24),
          const Text(
            'Муаллифон',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
          const SizedBox(height: 12),
          _AuthorCard(
            photoAsset: 'assets/authors/fakhriddin.png',
            name: 'Фахриддин Фузайлов',
            role: 'Ҳуқуқшинос, роҳбари ширкати ҳуқуқии «Вакил»',
            whatsapp: 'https://wa.me/+992987751005',
            telegram: 'https://t.me/Fakhriddin9900',
            instagram:
                'https://www.instagram.com/fakhriddin_lawyer?igsh=dnZsb3hnaWNzN2dn',
            onOpenLink: _openLink,
          ),
          const SizedBox(height: 14),
          _AuthorCard(
            photoAsset: 'assets/authors/rahimjon.png',
            name: 'Раҳимҷон Мирқосимов',
            role: 'Ҳуқуқшинос, адвокати коллегияи адвокатҳои «Суғд»',
            whatsapp: 'https://wa.me/+992052510909',
            telegram: 'https://t.me/+992920250081',
            instagram:
                'https://www.instagram.com/huquqi_man_?igsh=Ymh0NmFvOTNkcDcz',
            onOpenLink: _openLink,
          ),
          const SizedBox(height: 14),
          _AuthorCard(
            photoAsset: 'assets/authors/alijon.png',
            name: 'Алиҷон Эргашев',
            role: 'Full stack разработчик, роҳбари ширкати 1week.tj',
            whatsapp: 'https://wa.me/+992927203002',
            telegram: 'https://t.me/ALIJOn3002',
            instagram:
                'https://www.instagram.com/alijon_web?igsh=MTF3ZzdteHF3aGNvOQ==',
            onOpenLink: _openLink,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_stories_rounded, color: Colors.white, size: 32),
          SizedBox(height: 10),
          Text(
            'Дастгирии касбӣ барои ронандагони Тоҷикистон',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Китоби «Ҳуқуқи ронанда» — маълумоти амалӣ аз мутахассисони боэътимод.',
            style: TextStyle(
              color: Color(0xFFE8EAF6),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard({
    required Color accent,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorCard extends StatelessWidget {
  final String photoAsset;
  final String name;
  final String role;
  final String whatsapp;
  final String telegram;
  final String instagram;
  final Future<void> Function(String url) onOpenLink;

  const _AuthorCard({
    required this.photoAsset,
    required this.name,
    required this.role,
    required this.whatsapp,
    required this.telegram,
    required this.instagram,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: ColoredBox(
              color: const Color(0xFFF0F2F5),
              child: Image.asset(
                photoAsset,
                width: double.infinity,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  role,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialButton(
                      tooltip: 'WhatsApp',
                      onTap: () => _launch(onOpenLink, whatsapp, context),
                      child: const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: Color(0xFF25D366),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _SocialButton(
                      tooltip: 'Telegram',
                      onTap: () => _launch(onOpenLink, telegram, context),
                      child: const FaIcon(
                        FontAwesomeIcons.telegram,
                        color: Color(0xFF0088CC),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _SocialButton(
                      tooltip: 'Instagram',
                      onTap: () => _launch(onOpenLink, instagram, context),
                      child: const FaIcon(
                        FontAwesomeIcons.instagram,
                        color: Color(0xFFE1306C),
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _launch(
    Future<void> Function(String) onOpenLink,
    String url,
    BuildContext context,
  ) async {
    try {
      await onOpenLink(url);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пайванд кушода нашуд')),
        );
      }
    }
  }
}

class _SocialButton extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final VoidCallback onTap;

  const _SocialButton({
    required this.child,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ),
      ),
    );
  }
}
