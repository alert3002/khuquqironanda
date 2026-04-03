import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/book_model.dart';
import '../api/api_service.dart';
import 'book_reader_screen.dart';
import 'balance_screen.dart'; // <--- ИНРО ИЛОВА КАРДЕМ

class BookDetailScreen extends StatefulWidget {
  final Book book;
  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late Book _book;
  bool _isLoading = false;
  bool _isBookPurchased = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _checkPurchaseStatus();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Санҷиш: Оё китоб аллакай харида шудааст?
  void _checkPurchaseStatus() {
    // Истифодаи маълумоти аз сервер омада (isPurchased)
    setState(() {
      _isBookPurchased = _book.isPurchased;
    });
  }

  // Навсозии маълумот аз сервер ё кеш
  Future<void> _refreshBook() async {
    try {
      // Истифодаи getBookDetails барои гирифтани тафсилоти пурра
      final updatedBook = await ApiService.getBookDetails(_book.id);
      
      if (updatedBook != null && mounted) {
        setState(() {
          _book = updatedBook;
          _checkPurchaseStatus();
        });
      } else if (mounted) {
        // Агар маълумот наёфтем, аз рӯйхати китобҳо меҷӯем
        final books = await ApiService.getBooks();
        final foundBook = books.firstWhere(
          (b) => b.id == _book.id,
          orElse: () => _book,
        );
        
        setState(() {
          _book = foundBook;
          _checkPurchaseStatus();
        });
      }
    } catch (e) {
      print("Хатогӣ ҳангоми навсозӣ: $e");
    }
  }

  // Функсияи Харид бо Мантиқи "Баланс"
  void _buyBook() async {
    // 1. Диалоги тасдиқ
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Хариди китоб"),
        content: Text(
          "Нархи китоб: ${_book.price} сомонӣ.\nАз баланси шумо гирифта мешавад. Харидорӣ мекунед?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Не"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Харидан"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      // 2. Ирсоли дархост ба сервер
      Map<String, dynamic> result = await ApiService.buyBook(_book.id);

      setState(() => _isLoading = false);

      // 3. Таҳлили ҷавоб
      if (result['success'] == true) {
        // Агар муваффақ шуд
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Табрик! Китоб харида шуд."),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _refreshBook(); // Саҳифаро нав мекунем
      } else {
        // Агар хатогӣ шуд
        String errorMsg = result['error'] ?? "Хатогӣ";

        // --- САНҶИШИ БАЛАНС ---
        // Агар хатогӣ дар бораи "баланс", "маблағ" ё "funds" бошад
        if (errorMsg.toLowerCase().contains("баланс") ||
            errorMsg.toLowerCase().contains("маблағ") ||
            errorMsg.toLowerCase().contains("funds") ||
            errorMsg.toLowerCase().contains("required")) {
          if (mounted) {
            // Пешниҳоди гузариш ба саҳифаи Баланс
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Маблағ кифоя нест"),
                content: const Text(
                  "Барои хариди ин китоб маблағи кофӣ надоред. Мехоҳед балансро пур кунед?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Не"),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Диалогро мепӯшем
                      // Ба саҳифаи Баланс меравем
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BalanceScreen(),
                        ),
                      ).then((_) {
                        // Вақте бармегардад, маълумотро нав мекунем (шояд пул партофт)
                        _refreshBook();
                      });
                    },
                    child: const Text("Пур кардани баланси барномаи ҳуқуқи ронанда"),
                  ),
                ],
              ),
            );
          }
        } else {
          // Дигар намуди хатогиҳо (мас. аллакай харида шудааст)
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
            );
          }
        }
      }
    }
  }

  void _openReader() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookReaderScreen(book: _book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_book.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () async {
              setState(() => _isLoading = true);
              await _refreshBook();
              setState(() => _isLoading = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Маълумот нав карда шуд"),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            tooltip: "Навсозӣ",
          ),
        ],
      ),
      body: Column(
        children: [
          // Қисми Болоӣ (Header)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: ApiService.fixImageUrl(_book.coverImage),
                    width: 100,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 100,
                      height: 150,
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 100,
                      height: 150,
                      color: Colors.grey[300],
                      child: const Icon(Icons.book),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _book.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isBookPurchased
                          ? const Text(
                              "✅ Харида шуд",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : Text(
                              "${_book.price} сомонӣ",
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_isBookPurchased ? _openReader : _buyBook),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isBookPurchased
                                ? Colors.green
                                : Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isBookPurchased
                                      ? "Хонданро сар кунед"
                                      : "Харидани китоб",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Рӯйхати Бобҳо
          Expanded(
            child: ListView.builder(
              itemCount: _book.chapters.length,
              itemBuilder: (context, index) {
                final chapter = _book.chapters[index];
                bool isUnlocked = chapter.isFree || chapter.isPurchased;

                return ListTile(
                  title: Text(
                    chapter.title,
                    style: TextStyle(
                      color: isUnlocked ? Colors.black : Colors.grey,
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isUnlocked
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    child: Icon(
                      isUnlocked
                          ? Icons.play_arrow_rounded
                          : Icons.lock_outline,
                      color: isUnlocked ? Colors.blue : Colors.red,
                    ),
                  ),
                  trailing: isUnlocked
                      ? const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey,
                        )
                      : const Text(
                          "Пулакӣ",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                  onTap: () {
                    if (isUnlocked) {
                      _openReader();
                    } else {
                      _buyBook();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
