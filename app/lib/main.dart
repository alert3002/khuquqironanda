import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'services/pending_topup_watcher.dart';
import 'services/push_notification_service.dart';
import 'services/screen_security_service.dart';
import 'api/api_service.dart';
import 'utils/pdf_js_assets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Омодасозии Hive (Базаи Офлайн)
  await Hive.initFlutter();
  await Hive.openBox('settings'); // Барои сабти Токен ва настройкаҳо
  await Hive.openBox('cache_books'); // Барои сабти Китобҳо (Офлайн)
  await Hive.openBox('cache'); // Барои сабти Raw JSON (Forever Offline)

  Future.microtask(PdfJsAssets.ensureLoaded);

  // 2. Агар токен набошад, барнома ҳамчун "меҳмон" кушода мешавад,
  // то Play Console онро "холӣ" ҳисоб накунад.
  try {
    final box = Hive.box('settings');
    final token = box.get('token');
    final isGuest = box.get('is_guest', defaultValue: false) == true;
    final isReviewMode = box.get('review_mode', defaultValue: false) == true;
    if (token == null && !isGuest && !isReviewMode) {
      await box.put('is_guest', true);
    }
  } catch (_) {}

  PendingTopUpWatcher.instance.init();

  Future.microtask(() => PushNotificationService.instance.init());

  Future.microtask(() async {
    await ApiService.warmOfflineCache();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Китобхонаи Ман',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 13),
          bodyMedium: TextStyle(fontSize: 13),
          bodySmall: TextStyle(fontSize: 13),
          displayLarge: TextStyle(fontSize: 13),
          displayMedium: TextStyle(fontSize: 13),
          displaySmall: TextStyle(fontSize: 13),
          headlineLarge: TextStyle(fontSize: 13),
          headlineMedium: TextStyle(fontSize: 13),
          headlineSmall: TextStyle(fontSize: 13),
          titleLarge: TextStyle(fontSize: 13),
          titleMedium: TextStyle(fontSize: 13),
          titleSmall: TextStyle(fontSize: 13),
          labelLarge: TextStyle(fontSize: 13),
          labelMedium: TextStyle(fontSize: 13),
          labelSmall: TextStyle(fontSize: 13),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('tg'),
      ],
      builder: (context, child) {
        return ScreenCaptureGuard(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }
}
