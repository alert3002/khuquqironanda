/// Маълумоти бахши «Қоидаҳои ҳаракат дар роҳ».
/// PDF-ҳо ба `assets/traffic_rules/doc_XX.pdf` гузошта мешаванд (01–17).
class TrafficRulesMenuItem {
  final String id;
  final String title;
  final String? subtitle;

  const TrafficRulesMenuItem({
    required this.id,
    required this.title,
    this.subtitle,
  });
}

class LegalDocumentItem {
  final int number;
  final String title;
  /// Масири локалӣ, масалан `assets/traffic_rules/doc_01.pdf`
  final String? assetPath;
  /// URL-и сервер (агар PDF дар сервер бошад)
  final String? remoteUrl;

  const LegalDocumentItem({
    required this.number,
    required this.title,
    this.assetPath,
    this.remoteUrl,
  });

  bool get hasPdf =>
      (assetPath != null && assetPath!.isNotEmpty) ||
      (remoteUrl != null && remoteUrl!.isNotEmpty);
}

const List<TrafficRulesMenuItem> trafficRulesMenuItems = [
  TrafficRulesMenuItem(
    id: 'legal_acts_list',
    title: 'Рӯйхати санадҳои меъёрию ҳуқуқии дар китоб истифода шуда',
    subtitle: 'Расмӣ — рӯйхати 2',
  ),
];

const String legalActsListIntro =
    'Дар китоби мазкур санадҳои меъёрию ҳуқуқи (СМҲ) - и зерин истифода карда шудааст:';

const List<LegalDocumentItem> legalDocumentsList = [
  LegalDocumentItem(
    number: 1,
    title:
        'Конститутсяи Ҷумҳурии Тоҷикистон аз 6 ноябри соли 1994;',
    assetPath: 'assets/traffic_rules/doc_01.pdf',
  ),
  LegalDocumentItem(
    number: 2,
    title: 'Кодекси ҳуқуқвайронкунии маъмурии',
    assetPath: 'assets/traffic_rules/doc_02.pdf',
  ),
  LegalDocumentItem(
    number: 3,
    title:
        'Ҷумҳурии Тоҷикистон аз 31 декабри соли 2008, №455;',
    assetPath: 'assets/traffic_rules/doc_02.pdf',
  ),
  LegalDocumentItem(
    number: 4,
    title:
        'Кодекси мурофиаи ҳуқуқвайронкунии маъмурии Ҷумҳурии Тоҷикистон аз 22 июли соли 2013, №975;',
    assetPath: 'assets/traffic_rules/doc_03.pdf',
  ),
  LegalDocumentItem(
    number: 5,
    title:
        'Кодекси ҷиноятии Ҷумҳурии Тоҷикистон аз 21 майи соли 1998, №574;',
    assetPath: 'assets/traffic_rules/doc_04.pdf',
  ),
  LegalDocumentItem(
    number: 6,
    title:
        'Қонуни Ҷумҳурии Тоҷикистон «Дар бораи милитсия» аз 17 майи соли 2004, №41;',
    assetPath: 'assets/traffic_rules/doc_05.pdf',
  ),
  LegalDocumentItem(
    number: 7,
    title:
        'Қонуни Ҷумҳурии Тоҷикистон «Дар бораи ҳаракат дар роҳ» аз 17 майи соли 2017, №1533;',
    assetPath: 'assets/traffic_rules/doc_06.pdf',
  ),
  LegalDocumentItem(
    number: 8,
    title:
        'Қонуни Ҷумҳурии Тоҷикистон «Дар бораи дигар пардохтҳои ҳатмӣ ба буҷет» аз 28 июли соли 2006, №197;',
    assetPath: 'assets/traffic_rules/doc_07.pdf',
  ),
  LegalDocumentItem(
    number: 9,
    title:
        'Қонуни Ҷумҳурии Тоҷикистон «Дар бораи буҷети давлатии Ҷумҳурии Тоҷикистон барои соли 2026» аз 1 декабри соли 2025, №2203;',
    assetPath: 'assets/traffic_rules/doc_08.pdf',
  ),
  LegalDocumentItem(
    number: 10,
    title:
        'Қонуни Ҷумҳурии Тоҷикистон «Дар бораи муроҷиатҳои шахсони воқеӣ ва ҳуқуқӣ» аз 23 июли соли 2016, №1339;',
    assetPath: 'assets/traffic_rules/doc_09.pdf',
  ),
  LegalDocumentItem(
    number: 11,
    title:
        'Қонуни Ҷумҳурии Тоҷикистон «Дар бораи суғуртаи ҳатмии ҷавобгарии маданию ҳуқуқии соҳибони воситаҳои нақлиёт»',
    assetPath: 'assets/traffic_rules/doc_10.pdf',
  ),
  LegalDocumentItem(
    number: 12,
    title:
        'Қоидаҳои ҳаракат дар роҳ, ки бо қарори Ҳукумати Ҷумҳурии Тоҷикистон аз 29 июни соли 2017, №323;',
    assetPath: 'assets/traffic_rules/doc_11.pdf',
  ),
  LegalDocumentItem(
    number: 13,
    title:
        'Замимаи 17 ба қарори Ҳукумати Ҷумҳурии Тоҷикистон аз 8 сентябри соли 2025, №476 Меъёри пардохт барои иҷозати истифодаи воситаҳои нақлиёт бо шишаҳои сиёҳу хира;',
    assetPath: 'assets/traffic_rules/doc_12.pdf',
  ),
  LegalDocumentItem(
    number: 14,
    title:
        'Замимаи 20 ба қарори Ҳукумати Ҷумҳурии Тоҷикистон аз 8 сентябри соли 2025, №476 Меъёрҳои пардохт барои нобудсозӣ (утилизатсия)-и воситаҳои нақлиёти автомобилӣ;',
    assetPath: 'assets/traffic_rules/doc_13.pdf',
  ),
  LegalDocumentItem(
    number: 15,
    title:
        'Замимаи 21 ба қарори Ҳукумати Ҷумҳурии Тоҷикистон аз 8 сентябри соли 2025, №476 Меъёрҳои пардохт барои нобудсозӣ (утилизатсия)-и воситаҳои нақлиёти автомобилии ба ҳудуди гумрукии Ҷумҳурии Тоҷикистон воридшаванда;',
    assetPath: 'assets/traffic_rules/doc_14.pdf',
  ),
  LegalDocumentItem(
    number: 16,
    title:
        'Кодекси одоби касбии корманди милитсия, аз 17 феврали соли 2017;',
    assetPath: 'assets/traffic_rules/doc_16.pdf',
  ),
  LegalDocumentItem(
    number: 17,
    title:
        'Фармоиши ВКД Ҷумҳурии Тоҷикистон аз 10 октябри соли 2024, №766 «Дар бораи хушмуомилагӣ ва муносибати бо эҳтиромонаи кормандони мақомоти корҳои дохилӣ, хизматчиёни ҳарбии қӯшунҳои дохилӣ бо ҳамкасбон ва шаҳрвандон»;',
    assetPath: 'assets/traffic_rules/doc_17.pdf',
  ),
  LegalDocumentItem(
    number: 18,
    title: 'Дигар санадҳои меъёрию ҳуқуқӣ.',
  ),
];
