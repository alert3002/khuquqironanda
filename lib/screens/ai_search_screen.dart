import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/book_model.dart';
import 'balance_screen.dart';

class AiSearchScreen extends StatefulWidget {
  final Book? book;

  const AiSearchScreen({
    super.key,
    this.book,
  });

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  Book? _book;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add({
        'type': 'user',
        'text': query,
      });
      _isLoading = true;
    });

    _queryController.clear();
    _scrollToBottom();

    try {
      // Call AI search API (bookId can be null for global search)
      final result = await ApiService.searchAI(query, _book?.id);

      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _messages.add({
            'type': 'ai',
            'text': result['answer'] ?? 'Ҷавоб гирифта нашуд',
            'bookId': _book?.id,
            'isPurchased': _book?.isPurchased ?? false,
          });
        } else {
          _messages.add({
            'type': 'error',
            'text': result['error'] ?? 'Хатогӣ дар гирифтани ҷавоб',
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add({
          'type': 'error',
          'text': 'Хатогии пайвастшавӣ: $e',
        });
      });
    }

    _scrollToBottom();
  }

  Future<void> _buyBook() async {
    if (_book == null) return;
    
    // Navigate to balance screen
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BalanceScreen()),
    );

    // Refresh book status after returning from balance screen
    final updatedBook = await ApiService.getBookDetails(_book!.id);
    if (updatedBook != null && mounted) {
      setState(() {
        _book = updatedBook;
        // Update all messages with new purchase status
        for (var message in _messages) {
          if (message['type'] == 'ai' && message['bookId'] == _book!.id) {
            message['isPurchased'] = _book!.isPurchased;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_book != null ? "AI Ҷустуҷӯ: ${_book!.title}" : "AI Ҷустуҷӯ (Умуми)"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _book != null
                              ? "Саволҳои худро дар бораи китоб бипурсед"
                              : "Саволҳои худро дар бораи китобҳо бипурсед",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        // Loading indicator
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final message = _messages[index];
                      final isUser = message['type'] == 'user';
                      final isError = message['type'] == 'error';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              // AI/Book Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isError
                                      ? Colors.red[100]
                                      : Colors.blue[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isError
                                      ? Icons.error_outline
                                      : Icons.menu_book,
                                  color: isError
                                      ? Colors.red[700]
                                      : Colors.blue[700],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? Colors.blue[600]
                                      : isError
                                          ? Colors.red[50]
                                          : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message['text'],
                                      style: TextStyle(
                                        color: isUser
                                            ? Colors.white
                                            : isError
                                                ? Colors.red[900]
                                                : Colors.black87,
                                        fontSize: 15,
                                      ),
                                    ),
                                    // Show lock and buy button if book not purchased
                                    if (!isUser &&
                                        !isError &&
                                        message['isPurchased'] == false) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lock_outline,
                                            size: 16,
                                            color: Colors.orange[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Барои дидани ҷавоби пурра китобро харид кунед",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange[700],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _buyBook,
                                          icon: const Icon(Icons.shopping_cart, size: 16),
                                          label: const Text("Харидани китоб"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 12),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: _book != null
                            ? "Саволро дар бораи китоб бипурсед..."
                            : "Саволро дар бораи китобҳо бипурсед...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendQuery(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _sendQuery,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

