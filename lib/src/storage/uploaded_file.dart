import 'dart:io';

class UploadedFile {
  final String fieldName;
  final String filename;
  final String? contentType;
  final int? size; // file size in bytes
  final String? extension; // ".png", ".jpg"
  final DateTime uploadedAt; // auto timestamp
  final Stream<List<int>> content;

  UploadedFile({
    required this.fieldName,
    required this.filename,
    this.contentType,
    this.size,
    this.extension,
    DateTime? uploadedAt,
    required this.content,
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  Future<void> saveTo(String path) async {
    final file = File(path);
    final sink = file.openWrite();
    await content.pipe(sink);
    await sink.close();
  }
}
