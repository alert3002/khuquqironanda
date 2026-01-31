import 'package:app/screens/balance_screen.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../models/book_model.dart';
import '../models/subscription_plan_model.dart';
import '../models/user_model.dart';
import 'about_screen.dart';
import 'book_reader_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Book? _book;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  // Нишон додани нақшаҳои обуна
  void _showSubscriptionPlans() async {
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
    _showSubscriptionOptions();
  }

  // Иҷрои хариди обуна
  Future<void> _processSubscription(int planId) async {
    if (_book == null) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Лутфан ба система ворид шавед"),
            backgroundColor: Colors.red,
          ),
        );
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.grey[100],
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
                icon: const Icon(Icons.refresh, color: Colors.blue, size: 28),
                onPressed: _refreshBook,
                tooltip: "Навсозӣ",
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.blue, size: 28),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.person, color: Colors.blue, size: 28),
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          "Китоб ёфт нашуд",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text("Аз нав кӯшиш кардан"),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshBook,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Large Book Cover and Description
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.white,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Large Book Cover
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: ApiService.fixImageUrl(_book!.coverImage),
                                    width: 180,
                                    height: 250,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 180,
                                      height: 250,
                                      color: Colors.grey[300],
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      width: 180,
                                      height: 250,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.book, size: 50),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Description and Buy Button
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Description
                                      if (_book!.description.isNotEmpty)
                                        Text(
                                          _book!.description,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      const SizedBox(height: 12),
                                      // Subscription Button or Active Status
                                      if (_book!.isPurchased && _book!.expiresAt != null)
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.cyan.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.cyan, width: 2),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.cyan[700], size: 24),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    "Обуна фаъол \n аст ✅",
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: Colors.cyan,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Фаъол то: ${DateFormat('dd.MM.yyyy').format(_book!.expiresAt!)}",
                                                style: TextStyle(
                                                  color: Colors.cyan[700],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _isPurchasing ? null : _showSubscriptionPlans,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.cyan.shade300,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: _isPurchasing
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : const Text(
                                                    "Обуна шудан",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
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
                          const SizedBox(height: 8),
                          // Chapters List Header
                          
                          // Chapters List
                          Builder(
                            builder: (context) {
                              // Sort chapters by order
                              final sortedChapters = List<Chapter>.from(_book!.chapters)
                                ..sort((a, b) => a.order.compareTo(b.order));
                              
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sortedChapters.length,
                                itemBuilder: (context, index) {
                                  final chapter = sortedChapters[index];
                                  final isAccessible = chapter.isFree || chapter.isPurchased;
                              
                              // Format: "Боб X: Title" where X is the chapter order
                              final chapterTitle = "${chapter.title}";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 1),
                                color: Colors.white,
                                child: ListTile(
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          chapterTitle,
                                          style: TextStyle(
                                            color: isAccessible ? Colors.black : Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (chapter.isPremium)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.yellow[700],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            "PRO",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  leading: Icon(
                                    isAccessible ? Icons.lock_open : Icons.lock,
                                    color: isAccessible ? Colors.green : Colors.red,
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  onTap: () {
                                    if (isAccessible) {
                                      _openReader(chapterId: chapter.id);
                                    } else if (chapter.isPremium) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("Боби PRO"),
                                          content: const Text(
                                            "Ин боб танҳо дар тарифҳои PRO (180 ё 365 рӯз) дастрас аст. "
                                            "Лутфан тарифи худро иваз кунед.",
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text("Бекор"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _buyBook();
                                              },
                                              child: const Text("Иваз кардан"),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      _buyBook();
                                    }
                                  },
                                ),
                              );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
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