import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// Security Service - барои идоракунии ҳимояи экран
class SecurityService {
  static const String _securityEnabledKey = 'screen_security_enabled';
  
  // Фаъол кардани ҳимояи экран (default: true)
  static Future<void> enableScreenSecurity({bool enabled = true}) async {
    try {
      var box = Hive.box('settings');
      await box.put(_securityEnabledKey, enabled);
      print("✅ Screen security ${enabled ? 'enabled' : 'disabled'}");
      
      // NOTE: Барои тағйир додани FLAG_SECURE дар вақти иҷро,
      // бояд Method Channel бо MainActivity.kt истифода карда шавад.
      // Ҳоло, FLAG_SECURE дар MainActivity.kt фаъол аст.
    } catch (e) {
      print("❌ Error setting security: $e");
    }
  }
  
  // Санҷидани, оё ҳимоя фаъол аст
  static bool isScreenSecurityEnabled() {
    try {
      var box = Hive.box('settings');
      return box.get(_securityEnabledKey, defaultValue: true);
    } catch (e) {
      return true; // Default: enabled
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Омодасозии Hive (Базаи Офлайн)
  await Hive.initFlutter();
  await Hive.openBox('settings'); // Барои сабти Токен ва настройкаҳо
  await Hive.openBox('cache_books'); // Барои сабти Китобҳо (Офлайн)
  await Hive.openBox('cache'); // Барои сабти Raw JSON (Forever Offline)
  
  // 2. Хомӯш кардани ҳимояи экран (Allow screenshots)
  SecurityService.enableScreenSecurity(enabled: false);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Санҷидани, оё корбар дар 10 рӯзи охир ворид шудааст
  static bool _isLoginValid() {
    try {
      var box = Hive.box('settings');
      String? token = box.get('token');
      String? loginDateStr = box.get('login_date');
      
      if (token == null || loginDateStr == null) {
        return false;
      }
      
      try {
        final loginDate = DateTime.parse(loginDateStr);
        final now = DateTime.now();
        final difference = now.difference(loginDate).inDays;
        
        // Агар аз 10 рӯз зиёдтар гузашта бошад, токенро нест мекунем
        if (difference > 10) {
          box.delete('token');
          box.delete('login_date');
          box.delete('phone');
          print("⚠️ Login expired (${difference} days old). Token cleared.");
          return false;
        }
        
        print("✅ Login valid (${difference} days old)");
        return true;
      } catch (e) {
        print("❌ Error parsing login date: $e");
        return false;
      }
    } catch (e) {
      print("❌ Error checking login: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Китобхонаи Ман',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // Global text theme with fontSize 13
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
      // Localization delegates for DatePicker and other Material widgets
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('tg'), // Tajik
      ],
      // Санҷидани, оё корбар аллакай ворид шудааст
      home: _isLoginValid() ? const HomeScreen() : const LoginScreen(),
    );
  }
}
