import 'admin_announcement.dart';
import 'announcement_detail.dart';

/// Respuesta de GET /api/admin/anuncios/{id}: el contenido de la novedad, sea
/// cual sea su estado, con su vigencia y su posición en el carrusel. A
/// diferencia del detalle público, el servidor la entrega también cuando está
/// programada o vencida.
class AdminAnnouncementDetail {
  const AdminAnnouncementDetail({
    required this.id,
    required this.publishedAt,
    required this.status,
    this.title,
    this.summary,
    this.text,
    this.visibleFrom,
    this.visibleUntil,
    this.position,
    this.images = const [],
  });

  /// Los campos que pueden venir en `null` (título, resumen, texto, inicio,
  /// fin, posición e imágenes) no rompen la lectura; un estado desconocido, un
  /// id o una posición fuera de rango sí.
  factory AdminAnnouncementDetail.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    if (id <= 0) throw const FormatException('Identificador inválido');
    final position = json['posicion'] as int?;
    if (position != null &&
        (position < 1 || position > AdminAnnouncement.maxCarouselSlots)) {
      throw const FormatException('Posición inválida');
    }
    DateTime? parseOptional(Object? value) =>
        value == null ? null : DateTime.parse(value as String);
    final images = json['imagenes'] as List?;
    return AdminAnnouncementDetail(
      id: id,
      title: json['titulo'] as String?,
      summary: json['resumen'] as String?,
      text: json['texto'] as String?,
      publishedAt: DateTime.parse(json['publicadoEn'] as String),
      visibleFrom: parseOptional(json['vigenteDesde']),
      visibleUntil: parseOptional(json['vigenteHasta']),
      status: AnnouncementStatus.fromApi(json['estado']),
      position: position,
      images: List.unmodifiable([
        for (final image in images ?? const [])
          AnnouncementImage.fromJson(image as Map<String, dynamic>),
      ]),
    );
  }

  final int id;
  final String? title;
  final String? summary;
  final String? text;
  final DateTime publishedAt;
  final DateTime? visibleFrom;
  final DateTime? visibleUntil;
  final AnnouncementStatus status;

  /// De 1 a 5 si está en el carrusel; `null` si no.
  final int? position;

  final List<AnnouncementImage> images;

  String get displayTitle => title == null || title!.trim().isEmpty
      ? 'Novedad de la mutualista'
      : title!.trim();
}
