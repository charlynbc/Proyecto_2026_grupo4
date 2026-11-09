import '../models/announcement.dart';
import '../models/announcement_detail.dart';
import '../models/announcement_page.dart';
import 'announcements_repository.dart';

/// Solo para USE_FAKES y pruebas. No descarga imágenes ni utiliza la red.
class FakeAnnouncementsRepository implements AnnouncementsRepository {
  @override
  Future<AnnouncementPage> list({int page = 0}) async {
    if (page < 0) throw ArgumentError.value(page, 'page');
    final items = await latest();
    return AnnouncementPage(
      items: page == 0 ? items : [],
      page: page,
      total: items.length,
    );
  }

  @override
  Future<AnnouncementDetail> detail(int id) async {
    if (id != 1) throw const AnnouncementNotFoundException();
    return AnnouncementDetail(
      id: 1,
      title: 'Información de la mutualista',
      text: '**Novedad de ejemplo** para la vista con datos de prueba.',
      publishedAt: DateTime.utc(2026, 11, 1),
    );
  }

  @override
  Future<List<Announcement>> latest() async => [
    Announcement(
      id: 1,
      title: 'Información de la mutualista',
      summary: 'Novedad de ejemplo para la vista con datos de prueba.',
      publishedAt: DateTime.utc(2026, 11, 1),
    ),
  ];
}
