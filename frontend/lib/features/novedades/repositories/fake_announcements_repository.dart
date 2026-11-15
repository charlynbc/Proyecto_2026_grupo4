import '../../../core/network/api_exception.dart';
import '../models/announcement.dart';
import '../models/announcement_detail.dart';
import '../models/announcement_draft.dart';
import '../models/announcement_page.dart';
import 'announcements_repository.dart';

/// Una novedad de los datos de prueba, con su vigencia y su posición en el
/// carrusel (`null` si el administrador no la eligió).
class FakeAnnouncementEntry {
  const FakeAnnouncementEntry({
    required this.detail,
    this.visibleFrom,
    this.visibleUntil,
    this.position,
  });

  final AnnouncementDetail detail;

  /// Desde cuándo se ve (inclusive). Sin inicio, desde ya.
  final DateTime? visibleFrom;

  /// Hasta cuándo se ve (exclusivo). Sin fin, no vence.
  final DateTime? visibleUntil;

  final int? position;

  bool isVisibleAt(DateTime now) {
    final from = visibleFrom;
    final until = visibleUntil;
    return (from == null || !from.isAfter(now)) &&
        (until == null || until.isAfter(now));
  }
}

/// Solo para USE_FAKES y pruebas. No descarga imágenes ni utiliza la red.
class FakeAnnouncementsRepository implements AnnouncementsRepository {
  /// [now] es el reloj con que se valida el fin de la visibilidad y se decide
  /// qué novedades están vigentes; se puede reemplazar en pruebas. [seed]
  /// reemplaza los datos de prueba iniciales.
  FakeAnnouncementsRepository({
    DateTime Function()? now,
    List<FakeAnnouncementEntry>? seed,
  }) : _now = now ?? DateTime.now,
       _entries = [...(seed ?? _defaultSeed)];

  static final List<FakeAnnouncementEntry> _defaultSeed = [
    FakeAnnouncementEntry(
      detail: AnnouncementDetail(
        id: 1,
        title: 'Información de la mutualista',
        summary: 'Novedad de ejemplo para la vista con datos de prueba.',
        text: '**Novedad de ejemplo** para la vista con datos de prueba.',
        publishedAt: DateTime.utc(2026, 11, 1),
      ),
      position: 1,
    ),
  ];

  final DateTime Function() _now;
  final List<FakeAnnouncementEntry> _entries;

  /// Las novedades vigentes ahora: el listado, el detalle y el carrusel
  /// comparten esta regla y este reloj.
  Iterable<FakeAnnouncementEntry> get _visible {
    final now = _now();
    return _entries.where((entry) => entry.isVisibleAt(now));
  }

  @override
  Future<void> publish(AnnouncementDraft draft) async {
    // El mismo 400 que responde el servidor.
    final visibilityError = draft.validateVisibility(_now());
    if (visibilityError != null) throw ApiException(visibilityError);
    final nextId =
        _entries.fold(0, (max, e) => e.detail.id > max ? e.detail.id : max) + 1;
    _entries.insert(
      0,
      FakeAnnouncementEntry(
        detail: AnnouncementDetail(
          id: nextId,
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
        visibleFrom: draft.visibleFrom,
        visibleUntil: draft.visibleUntil,
      ),
    );
  }

  @override
  Future<AnnouncementPage> list({int page = 0}) async {
    if (page < 0) throw ArgumentError.value(page, 'page');
    final items = [for (final e in _visible) Announcement.fromDetail(e.detail)];
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
    // Como el servidor: una novedad fuera de vigencia responde 404.
    for (final entry in _visible) {
      if (entry.detail.id == id) return entry.detail;
    }
    throw const AnnouncementNotFoundException();
  }

  /// Solo las novedades con posición y vigentes, por posición ascendente. Las
  /// posiciones vacías no se rellenan.
  @override
  Future<List<Announcement>> carousel() async {
    final chosen = [
      for (final entry in _visible)
        if (entry.position != null) entry,
    ]..sort((a, b) => a.position!.compareTo(b.position!));
    return [for (final entry in chosen) Announcement.fromDetail(entry.detail)];
  }
}
