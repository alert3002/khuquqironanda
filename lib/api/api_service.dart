import 'dart:convert';
import 'dart:io' show Platform; // Барои санҷиши Android/iOS
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/book_model.dart';
import '../models/user_model.dart';

class ApiService {
  // --- ТАНЗИМОТИ ASOSӢ ---

  // Target Book ID for Single Book Application
  static const int targetBookId = 1;

  static Future<int> getSelectedBookId() async {
    try {
      var box = Hive.box('settings');
      final stored = box.get('selected_book_id');
      if (stored is int) return stored;
    } catch (_) {}
    return targetBookId;
  }

  static Future<void> setSelectedBookId(int bookId) async {
    try {
      var box = Hive.box('settings');
      await box.put('selected_book_id', bookId);
    } catch (_) {}
  }

  // URL-и серверро автоматӣ муайян мекунем
  static String get baseUrl {
    if (kIsWeb) {
      return "https://books.1week.tj/api"; // Барои Web
    } else if (Platform.isAndroid) {
      return "https://books.1week.tj/api"; // Прод
    } else {
      return "https://books.1week.tj/api"; // Прод
    }
  }

  static Future<Book?> _loadBundledSampleBook() async {
    try {
      final raw = await rootBundle.loadString('assets/sample_book.json');
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        return Book.fromJson(data);
      }
      if (data is Map) {
        return Book.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      print("❌ Error loading bundled sample book: $e");
    }
    return null;
  }

  static Future<List<Book>> _fallbackBooks() async {
    final sample = await _loadBundledSampleBook();
    if (sample != null) return [sample];
    return [];
  }

  // Функсияи ёрирасон барои сохтани Header (бо Токен)
  static Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    Map<String, String> headers = {'Content-Type': 'application/json'};

    if (auth) {
      var box = Hive.box('settings');
      String? token = box.get('token');
      if (token != null) {
        headers['Authorization'] = 'Token $token';
      }
    }
    return headers;
  }

  // Public helper for auth headers (for downloads/images)
  static Future<Map<String, String>> getAuthHeaders() async {
    return _getHeaders(auth: true);
  }

  // Функсия барои гирифтани ID-и дастгоҳ
  static Future<String> getDeviceId() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (kIsWeb) {
        // Барои Web, ID-и браузерро истифода мекунем
        final webInfo = await deviceInfo.webBrowserInfo;
        return webInfo.userAgent ?? 'web-unknown';
      } else if (Platform.isAndroid) {
        // Барои Android, AndroidId-ро истифода мекунем
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        // Барои iOS, identifierForVendor-ро истифода мекунем
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios-unknown';
      } else {
        return 'unknown-platform';
      }
    } catch (e) {
      print("❌ Error getting device ID: $e");
      return 'error-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // --- 1. АВТОРИЗАЦИЯ (AUTH) ---

  static Future<Map<String, dynamic>> sendCode(String phone) async {
    try {
      final deviceId = await getDeviceId();
      print("🚀 Sending SMS to: $phone (Device ID: $deviceId)");
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-code/'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({
          'phone': phone,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ SMS sent successfully");
        return {'success': true};
      } else if (response.statusCode == 403) {
        // Device restriction error
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'error': errorData['error'] ?? errorData['message'] ?? 'Device restriction',
          'statusCode': 403,
        };
      } else {
        print("❌ SMS Error: ${response.body}");
        return {
          'success': false,
          'error': 'Хатогӣ дар ирсоли СМС',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print("❌ Connection Error: $e");
      return {
        'success': false,
        'error': 'Хатогии пайвастшавӣ: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyCode(String phone, String code) async {
    try {
      final deviceId = await getDeviceId();
      print("🔐 Verifying code for: $phone (Device ID: $deviceId)");
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/verify-code/'),
        headers: await _getHeaders(auth: false),
        body: jsonEncode({
          'phone': phone,
          'code': code,
          'device_id': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String token = data['token'];

        // Сабти Токен, таърихи воридшавӣ ва device_id дар Hive
        var box = Hive.box('settings');
        await box.put('token', token);
        await box.put('phone', phone);
        await box.put('device_id', deviceId);
        await box.put('login_date', DateTime.now().toIso8601String());
        print("✅ Token saved: $token");
        print("✅ Device ID saved: $deviceId");
        print("✅ Login date saved: ${DateTime.now()}");
        return {'success': true};
      } else if (response.statusCode == 403) {
        // Device restriction error
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'error': errorData['error'] ?? errorData['message'] ?? 'Device restriction',
          'statusCode': 403,
        };
      } else {
        print("❌ Verify Error: ${response.body}");
        return {
          'success': false,
          'error': 'Код нодуруст аст',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print("❌ Error: $e");
      return {
        'success': false,
        'error': 'Хатогии пайвастшавӣ: $e',
      };
    }
  }

  // --- 2. ПРОФИЛИ КОРБАР ---

  static Future<User?> getUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // UTF-8 decode барои забони тоҷикӣ
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return User.fromJson(data);
      } else {
        print("⚠️ Profile Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error getting profile: $e");
    }
    return null;
  }

  // Навсозии профили корбар
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      // Ensure URL ends with a slash
      final url = '$baseUrl/auth/profile/';
      
      // Get headers with Authorization and Content-Type
      final headers = await _getHeaders(auth: true);
      
      // Encode the data as JSON
      final body = jsonEncode(data);
      
      print("🔄 PUT Request to: $url");
      print("📤 Request body: $body");
      print("📋 Headers: ${headers.keys}");
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print("📥 Response status: ${response.statusCode}");
      print("📥 Response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'data': responseData,
        };
      } else if (response.statusCode == 405 || response.statusCode == 404) {
        // Some backends accept PATCH instead of PUT
        final patchResponse = await http.patch(
          Uri.parse(url),
          headers: headers,
          body: body,
        );

        if (patchResponse.statusCode == 200) {
          final responseData = jsonDecode(utf8.decode(patchResponse.bodyBytes));
          return {
            'success': true,
            'data': responseData,
          };
        }
        try {
          final errorData = jsonDecode(utf8.decode(patchResponse.bodyBytes));
          return {
            'success': false,
            'error': errorData['error'] ??
                errorData['message'] ??
                'Хатогӣ: ${patchResponse.statusCode}',
          };
        } catch (_) {
          return {
            'success': false,
            'error': 'Хатогӣ: ${patchResponse.statusCode} - ${patchResponse.body}',
          };
        }
      } else {
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          return {
            'success': false,
            'error': errorData['error'] ?? errorData['message'] ?? 'Хатогӣ: ${response.statusCode}',
          };
        } catch (_) {
          return {
            'success': false,
            'error': 'Хатогӣ: ${response.statusCode} - ${response.body}',
          };
        }
      }
    } catch (e) {
      print("❌ Error in updateProfile: $e");
      return {
        'success': false,
        'error': 'Хатогии пайвастшавӣ: $e',
      };
    }
  }

  // Нест кардани ҳисоб
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/profile/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'error': errorData['error'] ?? 'Хатогӣ: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Хатогии пайвастшавӣ: $e',
      };
    }
  }

  // --- 3. КИТОБҲО (BOOKS) ---

  // Санҷиши пайвастшавӣ ба Интернет
  static Future<bool> _hasInternetConnection() async {
    try {
      final results = await Connectivity().checkConnectivity();
      // connectivity_plus v6+ returns List<ConnectivityResult>
      return results.any((r) => r != ConnectivityResult.none);
    } catch (e) {
      print("❌ Connectivity check error: $e");
      return false;
    }
  }

  // Сабти китобҳо дар Hive (Full JSON)
  static Future<void> _saveBooksToCache(List<Book> books) async {
    try {
      var box = Hive.box('cache_books');
      final booksJson = books.map((book) => {
        'id': book.id,
        'title': book.title,
        'description': book.description,
        'cover_image': book.coverImage,
        'price': book.price,
        'is_purchased': book.isPurchased,
        'chapters': book.chapters.map((ch) => {
          'id': ch.id,
          'title': ch.title,
          'content': ch.content,
          'is_free': ch.isFree,
          'order': ch.order,
          'is_purchased': ch.isPurchased,
        }).toList(),
      }).toList();
      await box.put('books_cache', booksJson);
      print("✅ Books cached successfully (${books.length} books)");
    } catch (e) {
      print("❌ Error caching books: $e");
    }
  }

  // Хондани китобҳо аз Hive
  static Future<List<Book>> _loadBooksFromCache() async {
    try {
      var box = Hive.box('cache_books');
      final booksJson = box.get('books_cache');
      if (booksJson != null && booksJson is List) {
        return booksJson.map((item) => Book.fromJson(Map<String, dynamic>.from(item))).toList();
      }
    } catch (e) {
      print("❌ Error loading books from cache: $e");
    }
    return [];
  }

  // Навсозии як китоб дар кеш (барои синхронизатсияи харид)
  static Future<void> _updateBookInCache(int bookId, bool isPurchased) async {
    try {
      var box = Hive.box('cache_books');
      final booksJson = box.get('books_cache');
      if (booksJson != null && booksJson is List) {
        final updatedBooks = booksJson.map((book) {
          if (book is Map && book['id'] == bookId) {
            // Навсозии китоб
            final updatedBook = Map<String, dynamic>.from(book);
            updatedBook['is_purchased'] = isPurchased;
            
            // Навсозии ҳамаи бобҳо
            if (updatedBook['chapters'] != null && updatedBook['chapters'] is List) {
              updatedBook['chapters'] = (updatedBook['chapters'] as List).map((chapter) {
                final updatedChapter = Map<String, dynamic>.from(chapter);
                updatedChapter['is_purchased'] = isPurchased;
                return updatedChapter;
              }).toList();
            }
            
            return updatedBook;
          }
          return book;
        }).toList();
        
        await box.put('books_cache', updatedBooks);
        print("✅ Book $bookId updated in cache (is_purchased: $isPurchased)");
      }
    } catch (e) {
      print("❌ Error updating book in cache: $e");
    }
  }

  // Сабти тафсилоти як китоб дар Hive
  static Future<void> _saveBookDetailsToCache(Book book) async {
    try {
      var box = Hive.box('cache_books');
      final bookJson = {
        'id': book.id,
        'title': book.title,
        'description': book.description,
        'cover_image': book.coverImage,
        'price': book.price,
        'is_purchased': book.isPurchased,
        'chapters': book.chapters.map((ch) => {
          'id': ch.id,
          'title': ch.title,
          'content': ch.content,
          'is_free': ch.isFree,
          'order': ch.order,
          'is_purchased': ch.isPurchased,
        }).toList(),
      };
      await box.put('book_${book.id}', bookJson);
      print("✅ Book details cached successfully for book ID: ${book.id}");
    } catch (e) {
      print("❌ Error caching book details: $e");
    }
  }

  // Хондани тафсилоти як китоб аз Hive
  static Future<Book?> _loadBookDetailsFromCache(int bookId) async {
    try {
      var box = Hive.box('cache_books');
      final bookJson = box.get('book_$bookId');
      if (bookJson != null && bookJson is Map) {
        return Book.fromJson(Map<String, dynamic>.from(bookJson));
      }
    } catch (e) {
      print("❌ Error loading book details from cache: $e");
    }
    return null;
  }

  static Future<List<Book>> getBooks() async {
    // Кӯшиш кардани гирифтани маълумот аз API
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/books/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Сабти raw JSON body дар кеш
        final rawJsonBody = utf8.decode(response.bodyBytes);
        try {
          var cacheBox = Hive.box('cache');
          await cacheBox.put('all_books', rawJsonBody);
          print("✅ Raw JSON saved to cache");
        } catch (e) {
          print("⚠️ Error saving raw JSON to cache: $e");
        }

        final data = jsonDecode(rawJsonBody);

        List<dynamic> list;
        // Санҷиши структураи API (Pagination ё List оддӣ)
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('results')) {
          list = data['results'];
        } else {
          list = [];
        }

        final books = list.map((item) => Book.fromJson(item)).toList();
        
        // Сабти маълумоти пурра дар кеш (Full JSON для backward compatibility)
        await _saveBooksToCache(books);
        
        return books;
      } else {
        print("⚠️ Books Error: ${response.statusCode}");
        // Агар хатогӣ рух дода бошад, аз кеш мехонем
        final cached = await _loadBooksFromCacheRaw();
        if (cached.isNotEmpty) return cached;
        return await _fallbackBooks();
      }
    } catch (e) {
      print("❌ Error getting books: $e");
      // Агар хатогӣ рух дода бошад, аз кеш мехонем
      final cached = await _loadBooksFromCacheRaw();
      if (cached.isNotEmpty) return cached;
      return await _fallbackBooks();
    }
  }

  // Fetch only the target book for Single Book Application
  static Future<Book?> fetchTargetBook() async {
    try {
      final books = await getBooks();
      final selectedId = await getSelectedBookId();
      final targetBook = books.firstWhere(
        (book) => book.id == selectedId,
        orElse: () => books.isNotEmpty ? books.first : throw Exception('No books found'),
      );
      return targetBook;
    } catch (e) {
      print("❌ Error fetching target book: $e");
      // Try to get from cache
      try {
        final cachedBooks = await _loadBooksFromCacheRaw();
        final targetBook = cachedBooks.firstWhere(
          (book) => book.id == targetBookId,
          orElse: () => cachedBooks.isNotEmpty ? cachedBooks.first : throw Exception('No cached books found'),
        );
        return targetBook;
      } catch (cacheError) {
        print("❌ Error loading target book from cache: $cacheError");
        return await _loadBundledSampleBook();
      }
    }
  }

  static Future<Map<String, dynamic>> fetchAboutPage() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/books/about/'),
        headers: await _getHeaders(auth: false),
      );
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (e) {
      // ignore
    }
    return {
      'title': 'Дар бораи мо',
      'content': '',
      'phone': '',
      'email': '',
      'telegram_url': '',
      'whatsapp_url': '',
    };
  }

  // Хондани китобҳо аз кеш (Raw JSON)
  static Future<List<Book>> _loadBooksFromCacheRaw() async {
    try {
      var cacheBox = Hive.box('cache');
      final rawJson = cacheBox.get('all_books');
      
      if (rawJson != null && rawJson is String) {
        print("📦 Loading books from raw JSON cache");
        final data = jsonDecode(rawJson);
        
        List<dynamic> list;
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('results')) {
          list = data['results'];
        } else {
          list = [];
        }
        
        final books = list.map((item) => Book.fromJson(item)).toList();
        print("✅ Loaded ${books.length} books from raw JSON cache");
        return books;
      }
    } catch (e) {
      print("❌ Error loading from raw JSON cache: $e");
    }
    
    // Fallback to old cache method
    final cachedBooks = await _loadBooksFromCache();
    if (cachedBooks.isNotEmpty) {
      print("📦 Loaded ${cachedBooks.length} books from old cache format");
      return cachedBooks;
    }
    
    print("⚠️ No cached data available");
    return [];
  }

  // Гирифтани тафсилоти як китоб
  static Future<Book?> getBookDetails(int bookId) async {
    // Санҷиши пайвастшавӣ
    final hasInternet = await _hasInternetConnection();

    if (hasInternet) {
      // Агар онлайн бошад, маълумотро аз API мегирем
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/books/$bookId/'),
          headers: await _getHeaders(),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final book = Book.fromJson(data);
          
          // Сабти маълумот дар кеш
          await _saveBookDetailsToCache(book);
          
          return book;
        } else {
          print("⚠️ Book Details Error: ${response.statusCode}");
        }
      } catch (e) {
        print("❌ Error getting book details: $e");
      }
    }

    // Агар офлайн бошад ё хатогӣ рух дода бошад, аз кеш мехонем
    final cachedBook = await _loadBookDetailsFromCache(bookId);
    if (cachedBook != null) {
      print("📦 Loaded book details from cache for book ID: $bookId");
      return cachedBook;
    }

    // Агар дар кеш маълумот набошад
    if (!hasInternet) {
      print("⚠️ No Internet connection and no cached data for book ID: $bookId");
    }
    
    return null;
  }

  // Ислоҳи URL-и расмҳо
  static String fixImageUrl(String url) {
    if (url.isEmpty) return "";
    if (kIsWeb) return url;
    // Барои телефони ҳақиқӣ, IP-и локалиро истифода мекунем
    if (url.contains("127.0.0.1")) {
      // Барои Emulator
      // return url.replaceAll("127.0.0.1", "10.0.2.2");
      // Барои телефони ҳақиқӣ - бояд бо IP-и локалии компютер иваз карда шавад
      // Барои телефони ҳақиқӣ - IP-и локалиро истифода мекунем
      return url.replaceAll("127.0.0.1", "192.168.0.101");
    }
    return url;
  }

  // --- 4. ХАРИДҲО (PURCHASES) ---

  // Харидани Китоб (legacy - for one-time purchase)
  static Future<Map<String, dynamic>> buyBook(int bookId) async {
    final result = await _postRequest('$baseUrl/buy-book/', {'book_id': bookId});
    
    // Агар харид муваффақ бошад, кешро навсозӣ мекунем
    if (result['success'] == true) {
      // Навсозии китоб дар кеш (is_purchased = true)
      await _updateBookInCache(bookId, true);
      print("✅ Book $bookId purchase synced to cache");
    }
    
    return result;
  }

  // Харидани обуна барои китоб
  static Future<Map<String, dynamic>> purchaseBook(int bookId, int planId) async {
    final result = await _postRequest(
      '$baseUrl/purchase-subscription/',
      {
        'plan_id': planId,
        'book_id': bookId, // Include book_id if backend supports it
      },
    );
    
    // Агар харид муваффақ бошад, кешро навсозӣ мекунем
    if (result['success'] == true) {
      // Навсозии китоб дар кеш
      await _updateBookInCache(bookId, true);
      print("✅ Book $bookId subscription synced to cache");
    }
    
    return result;
  }

  // Харидани Боб
  static Future<Map<String, dynamic>> purchaseChapter(int chapterId) async {
    return _postRequest('$baseUrl/chapters/$chapterId/purchase/', {});
  }

  // --- ОБУНА (SUBSCRIPTION) ---

  // Гирифтани рӯйхати нақшаҳои обуна
  static Future<List<Map<String, dynamic>>> fetchSubscriptionPlans() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/books/$targetBookId/'),
        headers: await _getHeaders(auth: false), // Public endpoint
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final plans = (data is Map<String, dynamic>) ? data['plans'] : null;
        if (plans is List) {
          return List<Map<String, dynamic>>.from(plans);
        }
      } else {
        print("❌ Error fetching subscription plans: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error fetching subscription plans: $e");
    }
    return [];
  }

  // Харидани нақшаи обуна
  static Future<Map<String, dynamic>> purchaseSubscription(int planId) async {
    return _postRequest(
      '$baseUrl/purchase-subscription/',
      {'plan_id': planId},
    );
  }

  // AI Search - Ҷустуҷӯи AI
  static Future<Map<String, dynamic>> searchAI(String query, int? bookId) async {
    final body = <String, dynamic>{
      'query': query,
    };
    
    // Only include book_id if it's not null (for global search)
    if (bookId != null) {
      body['book_id'] = bookId;
    }
    
    final result = await _postRequest('$baseUrl/ai-search/', body);
    
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>?;
      return {
        'success': true,
        'answer': data?['answer'] ?? data?['response'] ?? 'Ҷавоб гирифта нашуд',
      };
    } else {
      return {
        'success': false,
        'error': result['error'] ?? 'Хатогӣ дар гирифтани ҷавоб',
      };
    }
  }

  // Санҷиши дастрасӣ (Check Access)
  static Future<Map<String, dynamic>> checkChapterAccess(int chapterId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chapters/$chapterId/check-access/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
      return {
        'has_access': false,
        'error': 'Server Error: ${response.statusCode}',
      };
    } catch (e) {
      return {'has_access': false, 'error': e.toString()};
    }
  }

  // --- 5. ПАРДОХТ (PAYMENT) ---

  // Оғози пардохт ба воситаи SmartPay
  static Future<Map<String, dynamic>> initSmartpayPayment(
    double amount, {
    String? description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/smartpay/init/'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'amount': amount.toStringAsFixed(2),
          if (description != null && description.isNotEmpty)
            'description': description,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'payment_link': data['payment_link'],
          'html_form': data['html_form'],
          'order_id': data['order_id'],
        };
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'error': errorData['error'] ?? 'Хатогӣ: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Хатогии пайвастшавӣ: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPaymentHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/history/'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (e) {
      print("❌ Error fetching payment history: $e");
      return [];
    }
  }

  // Оғози пардохт ба воситаи DC Bank
  static Future<Map<String, dynamic>> initPayment(
    double amount, {
    int? bookId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/init/'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'amount': amount.toStringAsFixed(2),
          if (bookId != null) 'book_id': bookId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'payment_url': data['payment_url'],
          'xml_data': data['xml_data'],
          'html_form': data['html_form'],
          'order_id': data['order_id'],
        };
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'error': errorData['error'] ?? 'Хатогӣ: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Хатогии пайвастшавӣ: $e'};
    }
  }

  // Оғози пардохт ба воситаи Alif Mobi
  static Future<Map<String, dynamic>> initAlifPayment(
    double amount, {
    int? bookId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/alif/init/'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'amount': amount.toStringAsFixed(2),
          if (bookId != null) 'book_id': bookId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'payment_url': data['payment_url'],
          'html_form': data['html_form'],
          'order_id': data['order_id'],
        };
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'error': errorData['error'] ?? 'Хатогӣ: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Хатогии пайвастшавӣ: $e'};
    }
  }

  // --- ФУНКСИЯИ УМУМӢ БАРОИ POST REQUESTS ---
  static Future<Map<String, dynamic>> _postRequest(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final headers = await _getHeaders();
      // Агар токен набошад, хатогӣ медиҳем
      if (!headers.containsKey('Authorization')) {
        return {'success': false, 'error': 'Лутфан ба система ворид шавед.'};
      }

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      // Кӯшиш мекунем ҷавобро хонем
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = {};
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Хатогӣ: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Хатогии пайвастшавӣ: $e'};
    }
  }
}
