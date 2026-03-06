/// Model for a single driving theory exam question.
class ExamQuestion {
  final int id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? imageUrl; // Optional; null shows placeholder

  const ExamQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.imageUrl,
  });

  bool get isValid => options.length >= 2 && correctIndex >= 0 && correctIndex < options.length;
}

/// Sample driving theory questions (Tajik) for practice exam.
class ExamData {
  static const List<ExamQuestion> drivingTheoryQuestions = [
    ExamQuestion(
      id: 1,
      question: "Дар маҳаллаҳои истиқоматӣ ҳадди зиндагиро чӣ қадар муайян кардаанд?",
      options: ["20 км/соат", "40 км/соат", "60 км/соат", "80 км/соат"],
      correctIndex: 1,
    ),
    ExamQuestion(
      id: 2,
      question: "Чароғи қизил дар роҳ чӣ маъно дорад?",
      options: ["Ист", "Суръатро кам кунед", "Гузаред", "Диққат"],
      correctIndex: 0,
    ),
    ExamQuestion(
      id: 3,
      question: "Шабон дар роҳ чароғҳоро чӣ вақт истифода бурдан лозим аст?",
      options: ["Ҳамеша", "Фақат дар роҳҳои асосӣ", "Фақат дар борон", "Ихтиёрӣ"],
      correctIndex: 0,
    ),
    ExamQuestion(
      id: 4,
      question: "Ҳадди маблағи маскунии алкогол барои ронандагон чӣ қадар аст?",
      options: ["0%", "0.02%", "0.05%", "0.08%"],
      correctIndex: 0,
    ),
    ExamQuestion(
      id: 5,
      question: "Аз пешеравӣ чанд метр дуртар паркуния кардан лозим аст?",
      options: ["1 м", "3 м", "5 м", "10 м"],
      correctIndex: 2,
    ),
    ExamQuestion(
      id: 6,
      question: "Ронанда пеш аз сар кардани ҳаракат бояд чӣ кунад?",
      options: [
        "Фақат сигнал диҳад",
        "Белтҳоро баста, диққат кунад ва сигнал диҳад",
        "Фақат зеринаро санҷад",
        "Ҳеҷ чиз",
      ],
      correctIndex: 1,
    ),
    ExamQuestion(
      id: 7,
      question: "Аломати зарди духтарина дар чароғи роҳиён чӣ маъно дорад?",
      options: ["Ист", "Омода шавед ба ист", "Гузаред", "Суръатро кам кунед"],
      correctIndex: 1,
    ),
    ExamQuestion(
      id: 8,
      question: "Дар роҳи нам ва лойалок суръати ронанда бояд чӣ гуна бошад?",
      options: ["Муқаррарӣ", "Камтар аз муқаррарӣ", "Зиёдтар", "Ҳар гуна"],
      correctIndex: 1,
    ),
    ExamQuestion(
      id: 9,
      question: "Ҳангоми гузари пешераван аз қафои мошин чӣ кор кардан лозим аст?",
      options: [
        "Суръатро зиёд кунед",
        "Суръатро кам кунед, ҷой диҳед",
        "Сигнал диҳед",
        "Ронандро овоз кунед",
      ],
      correctIndex: 1,
    ),
    ExamQuestion(
      id: 10,
      question: "Белти бехатарӣ бояд кай баста шавад?",
      options: [
        "Фақат дар роҳҳои шаҳр",
        "Ҳамеша ҳангоми рондан",
        "Фақат дар роҳҳои зудгард",
        "Фақат дар шаб",
      ],
      correctIndex: 1,
    ),
  ];
}
