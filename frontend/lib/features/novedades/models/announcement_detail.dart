class AnnouncementImage {
  const AnnouncementImage({
    required this.id,
    required this.order,
    required this.url,
  });

  factory AnnouncementImage.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final order = json['orden'] as int;
    final url = json['url'] as String;
    final uri = Uri.tryParse(url);
    if (id <= 0 ||
        order < 0 ||
        uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !['https', 'http'].contains(uri.scheme)) {
      throw const FormatException('Imagen inválida');
    }
    return AnnouncementImage(id: id, order: order, url: url);
  }

  final int id;
  final int order;
  final String url;
}

/// Respuesta de GET /api/anuncios/{id} (#67). No completa contenido ausente.
class AnnouncementDetail {
  const AnnouncementDetail({
    required this.id,
    required this.publishedAt,
    this.title,
    this.summary,
    this.text,
    this.images = const [],
  });

  factory AnnouncementDetail.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    if (id <= 0) throw const FormatException('Identificador inválido');
    return AnnouncementDetail(
      id: id,
      title: json['titulo'] as String?,
      summary: json['resumen'] as String?,
      text: json['texto'] as String?,
      publishedAt: DateTime.parse(json['publicadoEn'] as String),
      images: List.unmodifiable([
        for (final image in json['imagenes'] as List)
          AnnouncementImage.fromJson(image as Map<String, dynamic>),
      ]),
    );
  }

  final int id;
  final DateTime publishedAt;
  final String? title;
  final String? summary;
  final String? text;
  final List<AnnouncementImage> images;
}
