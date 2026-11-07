/// Tarjeta de GET /api/anuncios (contrato #66), sin cargar el detalle.
class Announcement {
  const Announcement({
    required this.id,
    required this.publishedAt,
    this.title,
    this.summary,
    this.coverUrl,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    if (id <= 0) throw const FormatException('Identificador inválido');
    final cover = json['imagenPortada'] as Map<String, dynamic>?;
    final url = cover?['url'] as String?;
    if (cover != null && (url == null || url.trim().isEmpty)) {
      throw const FormatException('Portada incompleta');
    }
    return Announcement(
      id: id,
      title: json['titulo'] as String?,
      summary: json['resumen'] as String?,
      publishedAt: DateTime.parse(json['publicadoEn'] as String),
      coverUrl: url,
    );
  }

  final int id;
  final String? title;
  final String? summary;
  final DateTime publishedAt;
  final String? coverUrl;

  String get displayTitle => title == null || title!.trim().isEmpty
      ? 'Novedad de la mutualista'
      : title!.trim();
}
