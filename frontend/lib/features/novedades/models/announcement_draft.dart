import 'dart:typed_data';

class AnnouncementDraft {
  const AnnouncementDraft({
    required this.title,
    this.summary,
    this.text,
    this.images = const [],
  });

  final String title;
  final String? summary;
  final String? text;
  final List<AnnouncementImageUpload> images;
}

class AnnouncementImageUpload {
  const AnnouncementImageUpload({
    required this.name,
    required this.bytes,
    required this.subtype,
  });

  static const maxCount = 5;
  static const maxBytes = 5 * 1024 * 1024;

  final String name;
  final Uint8List bytes;
  final String subtype;
}
