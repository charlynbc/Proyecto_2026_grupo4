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

  static const maxTitleLength = 160;
  static const maxSummaryLength = 300;

  static String? validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Ingresá el título.';
    if (title.length > maxTitleLength) {
      return 'El título admite hasta $maxTitleLength caracteres.';
    }
    return null;
  }

  static String? validateSummary(String? value) {
    if ((value?.trim().length ?? 0) > maxSummaryLength) {
      return 'El resumen admite hasta $maxSummaryLength caracteres.';
    }
    return null;
  }

  String? validateContent() {
    if ((text?.trim().isEmpty ?? true) && images.isEmpty) {
      return 'Agregá texto o al menos una imagen.';
    }
    final countError = AnnouncementImageUpload.validateCount(images.length);
    if (countError != null) return countError;
    for (final image in images) {
      final error = image.validate();
      if (error != null) return error;
    }
    return null;
  }
}

class AnnouncementImageUpload {
  const AnnouncementImageUpload({
    required this.name,
    required this.bytes,
    required this.subtype,
  });

  static const maxCount = 5;
  static const maxBytes = 5 * 1024 * 1024;
  static const allowedExtensions = ['jpg', 'jpeg', 'png'];

  final String name;
  final Uint8List bytes;
  final String subtype;

  static String? validateCount(int count) =>
      count > maxCount ? 'Podés adjuntar hasta $maxCount imágenes.' : null;

  static String? validateSize(String name, int bytes) =>
      bytes > maxBytes ? '$name supera los 5 MB.' : null;

  static String invalidTypeMessage(String name) =>
      '$name no es una imagen JPEG o PNG válida.';

  static String? detectSubtype(String name, Uint8List bytes) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 ||
        !allowedExtensions.contains(name.substring(dot + 1).toLowerCase())) {
      return null;
    }
    return switch (bytes) {
      [0xff, 0xd8, 0xff, ...] => 'jpeg',
      [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...] => 'png',
      _ => null,
    };
  }

  String? validate() {
    final sizeError = validateSize(name, bytes.length);
    if (sizeError != null) return sizeError;
    return detectSubtype(name, bytes) == subtype
        ? null
        : invalidTypeMessage(name);
  }
}
