import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дар бораи мо'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[100],
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService.fetchAboutPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? {};
          final title = data['title']?.toString() ?? 'Дар бораи мо';
          final content = data['content']?.toString() ?? '';
          final phone = data['phone']?.toString() ?? '';
          final email = data['email']?.toString() ?? '';
          final telegram = data['telegram_url']?.toString() ?? '';
          final whatsapp = data['whatsapp_url']?.toString() ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (content.isNotEmpty)
                  HtmlWidget(
                    content,
                    textStyle: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                if (content.isEmpty)
                  const Text(
                    'Маълумот нест',
                    style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey),
                  ),
                const SizedBox(height: 16),
                if (phone.isNotEmpty || email.isNotEmpty)
                  const Text(
                    'Тамос:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                if (phone.isNotEmpty || email.isNotEmpty) const SizedBox(height: 6),
                if (phone.isNotEmpty || email.isNotEmpty)
                  Text(
                    [
                      if (phone.isNotEmpty) 'Телефон: $phone',
                      if (email.isNotEmpty) 'Email: $email',
                    ].join('\n'),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                if (telegram.isNotEmpty || whatsapp.isNotEmpty) const SizedBox(height: 12),
                if (telegram.isNotEmpty || whatsapp.isNotEmpty)
                  Row(
                    children: [
                      if (telegram.isNotEmpty)
                        IconButton(
                          onPressed: () => _openUrl(telegram),
                          icon: const Icon(Icons.telegram),
                        ),
                      
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
