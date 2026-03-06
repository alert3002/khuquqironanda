import 'dart:io' show Platform;

import 'package:app/screens/balance_screen.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';
import '../models/book_model.dart';
import '../models/subscription_plan_model.dart';
import '../models/user_model.dart';
import 'about_screen.dart';
import 'book_reader_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Dashboard theme
class _DashboardTheme {
  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF1565C0);
  static const Color accent = Color(0xFF00897B);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color cardBg = Colors.white;
  static const double cardRadius = 16.0;
}

class _HomeScreenState extends State<HomeScreen> {
  Book? _book;
  bool _isLoading = true;
  bool _isPurchasing = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openTelegramContact() async {
    final uri = Uri.parse('https://t.me/group1week');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Telegram кушода нашуд.")),
        );
      }
    }
  }

  void _showIOSContactAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Обуна ва бобҳои иловагӣ"),
        content: const Text(
          "Дар версияи iOS пардохтҳо дар дохили барнома ғайрифаъоланд.\n\n"
          "Барои пайваст кардани бобҳои иловагӣ ё гирифтани дастрасии пурра, "
          "лутфан ба администратор дар Telegram муроҷиат намоед.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Бекор"),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openTelegramContact();
            },
            icon: const Icon(Icons.send),
            label: const Text("Telegram"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    try {
      final selectedBook = await ApiService.fetchTargetBook();

      if (mounted) {
        setState(() {
          _book = selectedBook;
          _isLoading = false;
        });
        
        if (selectedBook == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Интернет нест ё китоб ёфт нашуд."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Error loading book data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _book = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Хатогӣ дар боркунии маълумот: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshBook() async {
    await _loadData();
  }

  bool get _isGuest {
    try {
      return Hive.box('settings').get('is_guest', defaultValue: false) == true;
    } catch (_) {
      return false;
    }
  }

  void _showSignInRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Воридшавӣ зарур аст"),
        content: const Text(
          "Барои дастрасӣ ба мундариҷаи пулакӣ лутфан ба система ворид шавед.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Бекор"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Hive.box('settings').delete('is_guest');
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Ворид шудан"),
          ),
        ],
      ),
    );
  }

  // Нишон додани нақшаҳои обуна
  void _showSubscriptionPlans() async {
    if (Platform.isIOS) {
      _showIOSContactAdminDialog();
      return;
    }
    if (_isGuest) {
      _showSignInRequiredDialog();
      return;
    }
    if (_book == null || _book!.plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Нақшаҳои обуна мавҷуд нестанд"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Гирифтани баланси корбар
    User? user;
    try {
      user = await ApiService.getUserProfile();
    } catch (e) {
      print("Error fetching user: $e");
    }

    final userBalance = user != null ? double.tryParse(user.balance) ?? 0.0 : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BookSubscriptionPlansBottomSheet(
        plans: _book!.plans,
        userBalance: userBalance,
        bookTitle: _book!.title,
        onPlanSelected: (plan) async {
          Navigator.of(context).pop();
          await _processSubscription(plan.id);
        },
      ),
    );
  }

  void _showSubscriptionOptions() {
    _showSubscriptionPlans();
  }

  void _buyBook() {
    if (Platform.isIOS) {
      _showIOSContactAdminDialog();
      return;
    }
    _showSubscriptionOptions();
  }

  // Иҷрои хариди обуна
  Future<void> _processSubscription(int planId) async {
    if (Platform.isIOS) {
      _showIOSContactAdminDialog();
      return;
    }
    if (_book == null) return;
    if (_isGuest) {
      _showSignInRequiredDialog();
      return;
    }

    // Гирифтани баланси корбар
    User? user;
    try {
      user = await ApiService.getUserProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Лутфан ба система ворид шавед"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (user == null) {
      if (mounted) {
        _showSignInRequiredDialog();
      }
      return;
    }

    final userBalance = double.tryParse(user.balance) ?? 0.0;
    final selectedPlan = _book!.plans.firstWhere((p) => p.id == planId);

    // Санҷиши баланс
    if (userBalance < selectedPlan.price) {
      _showLowBalanceDialog(
        "Барои хариди ин нақша баланси кофӣ надоред.\n\n"
        "Баланси шумо: ${user.balance} сомонӣ\n"
        "Нархи нақша: ${selectedPlan.formattedPrice}",
        selectedPlan.price,
        "Пур кардани баланси барномаи ҳуқуқи ронанда барои обуна: ${_book!.title} (${selectedPlan.name})",
      );
      return;
    }

    // Диалоги тасдиқ
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Хариди обуна"),
        content: Text(
          "Нақша: ${selectedPlan.name}\n"
          "Нарх: ${selectedPlan.formattedPrice}\n"
          "Муддат: ${selectedPlan.formattedDuration}\n\n"
          "Аз баланси шумо гирифта мешавад. Харидорӣ мекунед?",
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

    if (confirm != true) return;

    setState(() => _isPurchasing = true);

    try {
      Map<String, dynamic> result = await ApiService.purchaseBook(_book!.id, planId);

      setState(() => _isPurchasing = false);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Табрик! Обуна харида шуд."),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _refreshBook();
      } else {
        String errorMsg = result['error'] ?? "Хатогӣ";

        if (_isLowBalanceError(errorMsg)) {
          _showLowBalanceDialog(
            errorMsg.isNotEmpty
                ? errorMsg
                : "Маблағ кифоя нест. Мехоҳед балансро пур кунед?",
            selectedPlan.price,
            "Пур кардани баланси барномаи ҳуқуқи ронанда барои обуна: ${_book!.title} (${selectedPlan.name})",
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
            );
          }
        }
      }
    } catch (e) {
      setState(() => _isPurchasing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хатогии пайвастшавӣ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isLowBalanceError(String message) {
    final lower = message.toLowerCase();
    return lower.contains("баланс") ||
        lower.contains("маблағ") ||
        lower.contains("маблағ кифоя нест") ||
        lower.contains("funds") ||
        lower.contains("required") ||
        lower.contains("low balance") ||
        lower.contains("400");
  }

  void _showLowBalanceDialog(String message, double? requiredAmount, String? description) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Маблағ кифоя нест"),
        content: Text(message),
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
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BalanceScreen(
                    initialAmount: requiredAmount,
                    paymentDescription: description,
                    autoStartPayment: true,
                  ),
                ),
              ).then((_) {
                _refreshBook();
              });
            },
            child: const Text("Пур кардани баланс"),
          ),
        ],
      ),
    );
  }

  void _openReader({int? chapterId}) {
    if (_book != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookReaderScreen(
            book: _book!,
            initialChapterId: chapterId,
          ),
        ),
      );
    }
  }

  List<Chapter> get _sortedChapters {
    if (_book == null) return [];
    final list = List<Chapter>.from(_book!.chapters)
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  List<Chapter> get _filteredChapters {
    if (_searchQuery.trim().isEmpty) return _sortedChapters;
    final q = _searchQuery.trim().toLowerCase();
    return _sortedChapters.where((c) => c.title.toLowerCase().contains(q)).toList();
  }

  int get _accessibleChaptersCount =>
      _sortedChapters.where((c) => c.isFree || c.isPurchased).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: _DashboardTheme.surface,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                // App icon
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'img/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Book Title
                Expanded(
                  child: Text(
                    _book?.title ?? "Китоб",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _DashboardTheme.primary, size: 26),
                onPressed: _refreshBook,
                tooltip: "Навсозӣ",
              ),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded, color: _DashboardTheme.primary, size: 26),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.person_rounded, color: _DashboardTheme.primary, size: 26),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _book == null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _refreshBook,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProgressTracker(),
                          const SizedBox(height: 20),
                          _buildQuickSearch(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Категорияҳо'),
                          const SizedBox(height: 12),
                          _buildCategoryCards(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Қонунҳои назариявӣ'),
                          const SizedBox(height: 12),
                          _buildSubscriptionBanner(),
                          const SizedBox(height: 16),
                          _buildChaptersList(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "Китоб ёфт нашуд",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text("Аз нав кӯшиш кардан"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DashboardTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTracker() {
    final total = _sortedChapters.length;
    final accessible = _accessibleChaptersCount;
    final progress = total > 0 ? accessible / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_DashboardTheme.primary, _DashboardTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_DashboardTheme.cardRadius),
        boxShadow: [
          BoxShadow(
            color: _DashboardTheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  "Пайиравии пешравӣ",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Дастрас: $accessible аз $total боб",
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          if (_book!.isPurchased && _book!.expiresAt != null) ...[
            const SizedBox(height: 12),
            Text(
              "Обуна фаъол то ${DateFormat('dd.MM.yyyy').format(_book!.expiresAt!)}",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickSearch() {
    return Container(
      decoration: BoxDecoration(
        color: _DashboardTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: "Ҷустуҷӯи мақолаҳо дар қонунҳо...",
          prefixIcon: const Icon(Icons.search_rounded, color: _DashboardTheme.primary),
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _DashboardTheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A237E),
      ),
    );
  }

  Widget _buildCategoryCards() {
    return Row(
      children: [
        Expanded(
          child: _CategoryCard(
            icon: Icons.gavel_rounded,
            title: "Қонунҳои назариявӣ",
            subtitle: "${_sortedChapters.length} боб",
            color: const Color(0xFF1565C0),
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CategoryCard(
            icon: Icons.quiz_rounded,
            title: "Тестҳои амалӣ",
            subtitle: "Ба зудӣ",
            color: const Color(0xFF00897B),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Ба зудӣ дастрас мешавад.")),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CategoryCard(
            icon: Icons.traffic_rounded,
            title: "Аломатҳо",
            subtitle: "Китобхона",
            color: const Color(0xFF6A1B9A),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Ба зудӣ дастрас мешавад.")),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionBanner() {
    if (_book!.isPurchased && _book!.expiresAt != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _DashboardTheme.accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(_DashboardTheme.cardRadius),
          border: Border.all(color: _DashboardTheme.accent.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _DashboardTheme.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Обуна фаъол то ${DateFormat('dd.MM.yyyy').format(_book!.expiresAt!)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF004D40),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isPurchasing
            ? null
            : () {
                if (Platform.isIOS) {
                  _showIOSContactAdminDialog();
                } else {
                  _showSubscriptionPlans();
                }
              },
        borderRadius: BorderRadius.circular(_DashboardTheme.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _DashboardTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(_DashboardTheme.cardRadius),
            border: Border.all(color: _DashboardTheme.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _DashboardTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.workspace_premium_rounded, color: _DashboardTheme.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Дастрасии пурра",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _DashboardTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Обуна шавед барои ҳамаи мундариҷа",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              _isPurchasing
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 18, color: _DashboardTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChaptersList() {
    final chapters = _filteredChapters;
    if (chapters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isEmpty ? "Бобҳо ёфт нашуд" : "Ҷустуҷӯӣ натиҷа надод",
                style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        return _ChapterCard(
          chapter: chapter,
          onTap: () => _onChapterTap(chapter),
        );
      },
    );
  }

  void _onChapterTap(Chapter chapter) {
    final isAccessible = chapter.isFree || chapter.isPurchased;
    if (isAccessible) {
      _openReader(chapterId: chapter.id);
    } else if (chapter.isPremium) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Боби PRO"),
          content: const Text(
            "Ин боб танҳо дар тарифҳои PRO дастрас аст. Лутфан обуна гиред.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Бекор"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _DashboardTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _buyBook();
              },
              child: const Text("Обуна"),
            ),
          ],
        ),
      );
    } else {
      _buyBook();
    }
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_DashboardTheme.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _DashboardTheme.cardBg,
            borderRadius: BorderRadius.circular(_DashboardTheme.cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onTap;

  const _ChapterCard({required this.chapter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAccessible = chapter.isFree || chapter.isPurchased;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_DashboardTheme.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _DashboardTheme.cardBg,
              borderRadius: BorderRadius.circular(_DashboardTheme.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isAccessible
                        ? _DashboardTheme.accent.withOpacity(0.12)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isAccessible ? Icons.article_rounded : Icons.lock_rounded,
                    color: isAccessible ? _DashboardTheme.accent : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isAccessible ? const Color(0xFF1A237E) : Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (chapter.isPremium) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "PRO",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF57F17),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget барои BottomSheet-и нақшаҳои обунаи китоб
class BookSubscriptionPlansBottomSheet extends StatelessWidget {
  final List<SubscriptionPlan> plans;
  final double userBalance;
  final Function(SubscriptionPlan) onPlanSelected;
  final String? bookTitle;

  const BookSubscriptionPlansBottomSheet({
    super.key,
    required this.plans,
    required this.userBalance,
    required this.onPlanSelected,
    this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Row(
            children: [
              Icon(Icons.history, color: Colors.blue, size: 28),
              SizedBox(width: 12),
              Text(
                "Обуна шавед",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Баланси шумо: ${userBalance.toStringAsFixed(2)} сомонӣ",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                final canAfford = userBalance >= plan.price;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundColor: canAfford 
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      child: Icon(
                        Icons.star,
                        color: canAfford ? Colors.blue : Colors.grey,
                        size: 30,
                      ),
                    ),
                    title: Text(
                      plan.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          "Муддат: ${plan.formattedDuration}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.formattedPrice,
                          style: TextStyle(
                            color: canAfford ? Colors.green : Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!canAfford) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Баланс кифоя нест",
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: canAfford ? Colors.blue : Colors.grey,
                    ),
                    onTap: () {
                      if (canAfford) {
                        onPlanSelected(plan);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BalanceScreen(
                            initialAmount: plan.price,
                            paymentDescription:
                                "Пур кардани баланси ҳуқуқи ронанда барои обуна: ${bookTitle ?? 'Китоб'} (${plan.name})",
                            autoStartPayment: true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}