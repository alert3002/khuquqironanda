import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../api/api_service.dart';
import '../models/book_model.dart';

// Global state to track current book
class CurrentBookContext {
  static Book? currentBook;
  static final _controller = StreamController<Book?>.broadcast();
  static Stream<Book?> get stream => _controller.stream;

  static void setBook(Book? book) {
    currentBook = book;
    _controller.add(book);
  }

  static void dispose() {
    _controller.close();
  }
}

class GlobalAiButton extends StatefulWidget {
  final Widget child;

  const GlobalAiButton({
    super.key,
    required this.child,
  });

  @override
  State<GlobalAiButton> createState() => _GlobalAiButtonState();
}

class _GlobalAiButtonState extends State<GlobalAiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Book? _currentBook;

  @override
  void initState() {
    super.initState();
    _currentBook = CurrentBookContext.currentBook;

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start pulsing animation
    _animationController.repeat(reverse: true);

    // Listen to book context changes
    CurrentBookContext.stream.listen((book) {
      if (mounted) {
        setState(() {
          _currentBook = book;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showQuickAiSearch() async {
    // Always fetch target book to ensure we use the correct book
    Book? targetBook;
    try {
      targetBook = await ApiService.fetchTargetBook();
    } catch (e) {
      print("Error fetching target book: $e");
      // Fallback to current book context if available
      targetBook = _currentBook;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAiSearchSheet(
        book: targetBook,
      ),
    );
  }

  bool _shouldShowButton() {
    // Check if user is logged in by checking for token
    try {
      var box = Hive.box('settings');
      String? token = box.get('token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    final shouldShow = _shouldShowButton();
    
    return Stack(
      children: [
        widget.child,
        // Floating AI Button (only show if logged in)
        if (shouldShow)
          Positioned(
            bottom: 20,
            right: 20,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showQuickAiSearch,
                    borderRadius: BorderRadius.circular(35),
                    child: const Center(
                      child: Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class QuickAiSearchSheet extends StatefulWidget {
  final Book? book;

  const QuickAiSearchSheet({
    super.key,
    this.book,
  });

  @override
  State<QuickAiSearchSheet> createState() => _QuickAiSearchSheetState();
}

class _QuickAiSearchSheetState extends State<QuickAiSearchSheet> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _answer;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty || _isLoading) return;

    // Always use targetBookId from ApiService
    final targetBookId = ApiService.targetBookId;

    setState(() {
      _isLoading = true;
      _error = null;
      _answer = null;
    });

    try {
      final result = await ApiService.searchAI(query, targetBookId);

      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _answer = result['answer'] ?? 'Ҷавоб гирифта нашуд';
          _error = null;
        } else {
          _error = result['error'] ?? 'Хатогӣ дар гирифтани ҷавоб';
          _answer = null;
        }
      });

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Хатогии пайвастшавӣ: $e';
        _answer = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.smart_toy, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Ҷустуҷӯ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.book != null)
                        Text(
                          'Китоб: ${widget.book!.title}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        )
                      else
                        Text(
                          'Китоб: ID ${ApiService.targetBookId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content area
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red[900]),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_answer != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.menu_book, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _answer!,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Center(
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
                            "Саволро дар бораи китоб бипурсед",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Input bar
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
                        hintText: "Саволро бипурсед...",
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
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _search,
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

