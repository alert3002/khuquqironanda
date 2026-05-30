import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

const _pdfDirName = 'legal_documents_pdfs';

String _pdfFileName(int documentId) => 'legal_doc_$documentId.pdf';

Future<Directory> _pdfDirectory() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/$_pdfDirName');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<String?> filePdfPath(int documentId) async {
  if (documentId <= 0) return null;
  try {
    final file = File(
      '${(await _pdfDirectory()).path}/${_pdfFileName(documentId)}',
    );
    if (await file.exists()) {
      final size = await file.length();
      if (size > 0) return file.path;
    }
  } catch (_) {}
  return null;
}

Future<Uint8List?> readFilePdf(int documentId) async {
  final path = await filePdfPath(documentId);
  if (path == null) return null;
  try {
    final bytes = await File(path).readAsBytes();
    if (bytes.isEmpty) return null;
    return bytes;
  } catch (_) {
    return null;
  }
}

Future<String?> writeFilePdf(int documentId, Uint8List bytes) async {
  if (documentId <= 0 || bytes.isEmpty) return null;
  try {
    final file = File(
      '${(await _pdfDirectory()).path}/${_pdfFileName(documentId)}',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}
