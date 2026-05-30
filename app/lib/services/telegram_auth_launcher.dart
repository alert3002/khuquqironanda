import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_service.dart';

/// Воридшавии Telegram дар 1 қадам: браузер → Telegram → баргашт ба барнома.
class TelegramAuthLauncher {
  static const String _oauthStart =
      'https://books.1week.tj/telegram-login/oauth/start/';

  /// Token ё хатогӣ.
  static Future<({String? token, String? error})> signIn() async {
    final appLinks = AppLinks();
    final deviceId = await ApiService.getDeviceId();
    final startUri = Uri.parse(_oauthStart).replace(
      queryParameters: {
        'app': '1',
        'device_id': deviceId,
      },
    );

    final completer = Completer<({String? token, String? error})>();
    StreamSubscription<Uri>? sub;
    Timer? timeout;

    void finish({String? token, String? error}) {
      if (completer.isCompleted) return;
      timeout?.cancel();
      sub?.cancel();
      completer.complete((token: token, error: error));
    }

    bool handleUri(Uri? uri) {
      if (uri == null) return false;
      if (uri.scheme != 'khuquqironanda' || uri.host != 'auth') return false;
      final token = uri.queryParameters['token'];
      final err = uri.queryParameters['error'];
      if (token != null && token.isNotEmpty) {
        finish(token: token);
        return true;
      }
      finish(error: err ?? 'Хатогии воридшавӣ');
      return true;
    }

    sub = appLinks.uriLinkStream.listen(handleUri);

    try {
      final initial = await appLinks.getInitialLink();
      if (handleUri(initial)) {
        return completer.future;
      }
    } catch (_) {}

    timeout = Timer(const Duration(minutes: 5), () {
      finish(error: 'Вақт тамом шуд. Аз нав кӯшиш кунед.');
    });

    final opened = await launchUrl(
      startUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      finish(error: 'Браузер кушода нашуд');
    }

    return completer.future;
  }
}
