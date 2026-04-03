import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exam_question_model.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  static const _questions = ExamData.drivingTheoryQuestions;
  int _currentIndex = 0;
  final List<int?> _selectedAnswers = List.filled(_questions.length, null);
  bool _examCompleted = false;

  int get _correctCount {
    int n = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] != null && _selectedAnswers[i] == _questions[i].correctIndex) n++;
    }
    return n;
  }

  int get _incorrectCount => _questions.length - _correctCount;

  double get _percentage => _questions.isEmpty ? 0 : (_correctCount / _questions.length) * 100;

  bool get _passed => _percentage >= 70;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _selectAnswer(int optionIndex) {
    if (_examCompleted) return;
    setState(() => _selectedAnswers[_currentIndex] = optionIndex);
  }

  void _nextOrSubmit() {
    if (_selectedAnswers[_currentIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Лутфан як ҷавобро интихоб кунед"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _examCompleted = true);
    }
  }

  void _previous() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _restartExam() {
    setState(() {
      _currentIndex = 0;
      for (int i = 0; i < _selectedAnswers.length; i++) _selectedAnswers[i] = null;
      _examCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_examCompleted) {
      return _buildResultSummary();
    }
    return _buildQuestionView();
  }

  Widget _buildQuestionView() {
    final q = _questions[_currentIndex];
    final selected = _selectedAnswers[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Тести назариявӣ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1A237E),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0D47A1)),
          onPressed: () => _showExitConfirm(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Савол ${_currentIndex + 1} аз ${_questions.length}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      q.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildImagePlaceholder(q),
                    const SizedBox(height: 24),
                    const Text(
                      "Ҷавобро интихоб кунед:",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(q.options.length, (i) {
                      final isSelected = selected == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OptionCard(
                          label: q.options[i],
                          optionLetter: String.fromCharCode(0x41 + i),
                          isSelected: isSelected,
                          onTap: () => _selectAnswer(i),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            _buildBottomBar(isLast),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(ExamQuestion q) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: q.imageUrl != null && q.imageUrl!.isNotEmpty
            ? Image.network(q.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderIcon())
            : _placeholderIcon(),
      ),
    );
  }

  Widget _placeholderIcon() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            "Тасвир",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isLast) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentIndex > 0)
            TextButton.icon(
              onPressed: _previous,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: const Text("Қафо"),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
              ),
            ),
          if (_currentIndex > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _nextOrSubmit,
              icon: Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 22),
              label: Text(isLast ? "Анҷом додан" : "Ба саволи оянда"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummary() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Натиҷаи тест",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1A237E),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Хона", style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _passed ? const Color(0xFF00897B).withOpacity(0.12) : Colors.orange.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _passed ? const Color(0xFF00897B) : Colors.orange,
                    width: 4,
                  ),
                ),
                child: Icon(
                  _passed ? Icons.emoji_events_rounded : Icons.refresh_rounded,
                  size: 72,
                  color: _passed ? const Color(0xFF00897B) : Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _passed ? "Табрик! Шумо гузаштед" : "Такрор кунед",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _passed ? const Color(0xFF004D40) : Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${_correctCount} дуруст, ${_incorrectCount} нодуруст • ${_percentage.toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 32),
              _buildScoreCard("Ҷавобҳои дуруст", _correctCount, _questions.length, const Color(0xFF00897B)),
              const SizedBox(height: 12),
              _buildScoreCard("Ҷавобҳои нодуруст", _incorrectCount, _questions.length, Colors.orange),
              const SizedBox(height: 28),
              _buildWrongAnswersSection(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _restartExam,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text("Такрор кардани тест"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home_rounded, size: 20),
                  label: const Text("Бозгашт ба саҳифаи асосӣ"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D47A1),
                    side: const BorderSide(color: Color(0xFF0D47A1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(String label, int value, int total, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A237E),
            ),
          ),
          Text(
            "$value / $total",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrongAnswersSection() {
    final wrongIndices = <int>[];
    for (int i = 0; i < _questions.length; i++) {
      if (_selectedAnswers[i] != null && _selectedAnswers[i] != _questions[i].correctIndex) {
        wrongIndices.add(i);
      }
    }
    if (wrongIndices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Ҷавобҳои нодуруст:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 12),
        ...wrongIndices.map((i) {
          final q = _questions[i];
          final correctOption = q.options[q.correctIndex];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.question,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Ҷавоби дуруст: $correctOption",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showExitConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Баромадан аз тест?"),
        content: const Text(
          "Агар баромада шавед, натиҷаи то ҳол сабт намешавад. Мутмаин ҳастед?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Бекор"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Баромадан"),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final String optionLetter;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.optionLetter,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00897B).withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  optionLetter,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: const Color(0xFF1A237E),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF00897B), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
