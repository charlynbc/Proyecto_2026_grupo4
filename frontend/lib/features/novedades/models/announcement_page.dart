import 'announcement.dart';

/// Página de Cartelera (#66). Inicio mantiene su consulta de cinco tarjetas.
class AnnouncementPage {
  const AnnouncementPage({
    required this.items,
    required this.page,
    required this.total,
  });

  static const pageSize = 10;

  factory AnnouncementPage.fromJson(Map<String, dynamic> json) {
    final page = json['page'] as int;
    final size = json['size'] as int;
    final total = json['total'] as int;
    final items = [
      for (final item in json['items'] as List)
        Announcement.fromJson(item as Map<String, dynamic>),
    ];
    if (page < 0 || size != pageSize || total < 0 || items.length > pageSize) {
      throw const FormatException('Página de novedades inválida');
    }
    return AnnouncementPage(
      items: List.unmodifiable(items),
      page: page,
      total: total,
    );
  }

  final List<Announcement> items;
  final int page;
  final int total;

  bool get hasNext => (page + 1) * pageSize < total;
}
