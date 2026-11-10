import '../models/announcement.dart';
import '../models/announcement_detail.dart';
import '../models/announcement_draft.dart';
import '../models/announcement_page.dart';
import 'announcements_repository.dart';

/// Solo para USE_FAKES y pruebas. No descarga imágenes ni utiliza la red.
class FakeAnnouncementsRepository implements AnnouncementsRepository {
  final _published = <AnnouncementDetail>[];

  @override
  Future<void> publish(AnnouncementDraft draft) async {
    _published.insert(
      0,
      AnnouncementDetail(
        id: _published.length + 2,
        title: draft.title,
        summary: draft.summary,
        text: draft.text,
        publishedAt: DateTime.now(),
        images: [
          for (final (index, image) in draft.images.indexed)
            AnnouncementImage(
              id: index + 1,
              order: index,
              url: Uri.dataFromBytes(
                image.bytes,
                mimeType: 'image/${image.subtype}',
              ).toString(),
            ),
        ],
      ),
    );
  }

  @override
  Future<AnnouncementPage> list({int page = 0}) async {
    if (page < 0) throw ArgumentError.value(page, 'page');
    final items = _cards();
    return AnnouncementPage(
      items: items
          .skip(page * AnnouncementPage.pageSize)
          .take(AnnouncementPage.pageSize)
          .toList(),
      page: page,
      total: items.length,
    );
  }

  @override
  Future<AnnouncementDetail> detail(int id) async {
    for (final announcement in _published) {
      if (announcement.id == id) return announcement;
    }
    if (id != 1) throw const AnnouncementNotFoundException();
    return AnnouncementDetail(
      id: 1,
      title: 'Información de la mutualista',
      text: '**Novedad de ejemplo** para la vista con datos de prueba.',
      publishedAt: DateTime.utc(2026, 11, 1),
    );
  }

  @override
  Future<List<Announcement>> latest() async => _cards().take(5).toList();

  List<Announcement> _cards() => [
    for (final detail in _published)
      Announcement(
        id: detail.id,
        title: detail.title,
        summary: detail.summary,
        publishedAt: detail.publishedAt,
        coverUrl: detail.images.firstOrNull?.url,
      ),
    Announcement(
      id: 1,
      title: 'Información de la mutualista',
      summary: 'Novedad de ejemplo para la vista con datos de prueba.',
      publishedAt: DateTime.utc(2026, 11, 1),
    ),
  ];
}
