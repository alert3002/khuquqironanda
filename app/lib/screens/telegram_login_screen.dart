import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/api_service.dart';
import 'home_screen.dart';

/// Воридшавӣ тавассути Telegram Login Widget.
/// Саҳифа бояд аз https://books.1week.tj/telegram-login/ бор шавад
/// (дар BotFather: /setdomain → books.1week.tj).
class TelegramLoginScreen extends StatefulWidget {
  const TelegramLoginScreen({super.key});

  static const String loginPageUrl =
      'https://books.1week.tj/telegram-login/';

  @override
  State<TelegramLoginScreen> createState() => _TelegramLoginScreenState();
}

class _TelegramLoginScreenState extends State<TelegramLoginScreen> {
  bool _loading = false;
  String? _error;
  Future<String> _pageUrl() async {
    final deviceId = await ApiService.getDeviceId();
    final uri = Uri.parse(TelegramLoginScreen.loginPageUrl).replace(
      queryParameters: {
        'app': '1',
        'device_id': deviceId,
      },
    );
    return uri.toString();
  }

  Future<void> _finishWithToken(String token) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final deviceId = await ApiService.getDeviceId();
    final box = Hive.box('settings');
    await box.put('token', token);
    await box.put('device_id', deviceId);
    await box.put('login_date', DateTime.now().toIso8601String());
    await box.delete('is_guest');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _onTelegramUser(Map<String, dynamic> user) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.loginWithTelegram(user);

    if (!mounted) return;

    if (result['success'] == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
      return;
    }

    setState(() {
      _loading = false;
      _error = result['error']?.toString() ?? 'Хатогӣ';
    });
  }

  void _tryHandleSuccessUrl(Uri? uri) {
    if (uri == null) return;
    final params = uri.queryParameters;
    if (params['success'] == '1' && params['token'] != null) {
      _finishWithToken(params['token']!);
      return;
    }
    final err = params['error'];
    if (err != null && err.isNotEmpty && mounted) {
      setState(() {
        _error = Uri.decodeComponent(err);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telegram'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: Stack(
        children: [
          FutureBuilder<String>(
                  future: _pageUrl(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return InAppWebView(
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        thirdPartyCookiesEnabled: true,
                        sharedCookiesEnabled: true,
                      ),
                      initialUrlRequest: URLRequest(
                        url: WebUri(snapshot.data!),
                      ),
                      onWebViewCreated: (controller) {
                        controller.addJavaScriptHandler(
                          handlerName: 'telegramAuth',
                          callback: (args) async {
                            if (args.isEmpty) return;
                            final raw = args.first;
                            if (raw is Map) {
                              await _onTelegramUser(
                                Map<String, dynamic>.from(raw),
                              );
                            } else if (raw is String) {
                              final decoded = jsonDecode(raw);
                              if (decoded is Map) {
                                await _onTelegramUser(
                                  Map<String, dynamic>.from(decoded),
                                );
                              }
                            }
                          },
                        );
                      },
                      onLoadStop: (controller, url) {
                        _tryHandleSuccessUrl(url);
                      },
                      shouldOverrideUrlLoading: (controller, action) async {
                        final url = action.request.url;
                        if (url != null &&
                            url.host.contains('books.1week.tj') &&
                            url.path.contains('telegram-login')) {
                          _tryHandleSuccessUrl(url);
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                    );
                  },
                ),
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
