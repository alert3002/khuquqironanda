class LegalDocumentModel {
  final int id;
  final int order;
  final String title;
  final String? pdfUrl;
  final String? assetPath;
  final bool hasPdf;

  const LegalDocumentModel({
    required this.id,
    required this.order,
    required this.title,
    this.pdfUrl,
    this.assetPath,
    required this.hasPdf,
  });

  factory LegalDocumentModel.fromJson(Map<String, dynamic> json) {
    final pdf = json['pdf_url']?.toString().trim();
    return LegalDocumentModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      order: json['order'] is int
          ? json['order'] as int
          : int.tryParse('${json['order']}') ?? 0,
      title: json['title']?.toString() ?? '',
      pdfUrl: (pdf != null && pdf.isNotEmpty) ? pdf : null,
      hasPdf: json['has_pdf'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'title': title,
        'pdf_url': pdfUrl,
        'has_pdf': hasPdf,
      };
}

class LegalDocumentsPageData {
  final String title;
  final String intro;
  final List<LegalDocumentModel> documents;

  const LegalDocumentsPageData({
    required this.title,
    required this.intro,
    required this.documents,
  });

  factory LegalDocumentsPageData.fromJson(Map<String, dynamic> json) {
    final list = json['documents'];
    return LegalDocumentsPageData(
      title: json['title']?.toString() ??
          'Рӯйхати санадҳои меъёрию ҳуқуқии дар китоб истифода шуда',
      intro: json['intro']?.toString() ?? '',
      documents: list is List
          ? list
              .whereType<Map>()
              .map(
                (e) => LegalDocumentModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'intro': intro,
        'documents': documents.map((d) => d.toJson()).toList(),
      };
}
