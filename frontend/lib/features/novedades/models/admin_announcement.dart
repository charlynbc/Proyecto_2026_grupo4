/// El estado de una novedad según su vigencia, como lo calcula el servidor.
enum AnnouncementStatus {
  scheduled('PROGRAMADO', 'Programado'),
  active('VIGENTE', 'Vigente'),
  expired('VENCIDO', 'Vencido');

  const AnnouncementStatus(this.apiValue, this.label);

  /// El valor que manda el servidor en `estado`.
  final String apiValue;

  /// El texto que se muestra: el estado no depende solo del color.
  final String label;

  static AnnouncementStatus fromApi(Object? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    throw FormatException('Estado inválido: $value');
  }
}

/// Una fila de GET /api/admin/anuncios: la novedad con su vigencia, su estado y
/// su posición en el carrusel del Inicio.
class AdminAnnouncement {
  const AdminAnnouncement({
    required this.id,
    required this.publishedAt,
    required this.status,
    this.title,
    this.visibleFrom,
    this.visibleUntil,
    this.position,
  });

  factory AdminAnnouncement.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    if (id <= 0) throw const FormatException('Identificador inválido');
    final position = json['posicion'] as int?;
    if (position != null && (position < 1 || position > maxCarouselSlots)) {
      throw const FormatException('Posición inválida');
    }
    DateTime? parseOptional(Object? value) =>
        value == null ? null : DateTime.parse(value as String);
    return AdminAnnouncement(
      id: id,
      title: json['titulo'] as String?,
      publishedAt: DateTime.parse(json['publicadoEn'] as String),
      visibleFrom: parseOptional(json['vigenteDesde']),
      visibleUntil: parseOptional(json['vigenteHasta']),
      status: AnnouncementStatus.fromApi(json['estado']),
      position: position,
    );
  }

  /// Cuántas novedades entran en el carrusel.
  static const maxCarouselSlots = 5;

  final int id;
  final String? title;
  final DateTime publishedAt;
  final DateTime? visibleFrom;
  final DateTime? visibleUntil;
  final AnnouncementStatus status;

  /// De 1 a 5 si está en el carrusel; `null` si no.
  final int? position;

  String get displayTitle => title == null || title!.trim().isEmpty
      ? 'Novedad de la mutualista'
      : title!.trim();
}

/// Una posición del carrusel y la novedad que la ocupa.
class CarouselSlot {
  const CarouselSlot({required this.position, required this.announcementId});

  factory CarouselSlot.fromJson(Map<String, dynamic> json) => CarouselSlot(
    position: json['posicion'] as int,
    announcementId: json['anuncioId'] as int,
  );

  final int position;
  final int announcementId;

  Map<String, Object> toJson() => {
    'posicion': position,
    'anuncioId': announcementId,
  };
}
