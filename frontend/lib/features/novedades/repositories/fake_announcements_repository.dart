import 'dart:math' as math;

import '../../../core/network/api_exception.dart';
import '../models/admin_announcement.dart';
import '../models/admin_announcement_detail.dart';
import '../models/announcement.dart';
import '../models/announcement_detail.dart';
import '../models/announcement_draft.dart';
import '../models/announcement_edit.dart';
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

  /// La regla del servidor: programada si el inicio todavía no llegó, vencida
  /// si el fin ya llegó, vigente en cualquier otro caso.
  AnnouncementStatus statusAt(DateTime now) {
    final from = visibleFrom;
    final until = visibleUntil;
    if (from != null && from.isAfter(now)) return AnnouncementStatus.scheduled;
    if (until != null && !until.isAfter(now)) return AnnouncementStatus.expired;
    return AnnouncementStatus.active;
  }

  bool isVisibleAt(DateTime now) => statusAt(now) == AnnouncementStatus.active;

  FakeAnnouncementEntry withValidity(DateTime? from, DateTime? until) =>
      FakeAnnouncementEntry(
        detail: detail,
        visibleFrom: from,
        visibleUntil: until,
        position: position,
      );

  FakeAnnouncementEntry withDetail(AnnouncementDetail newDetail) =>
      FakeAnnouncementEntry(
        detail: newDetail,
        visibleFrom: visibleFrom,
        visibleUntil: visibleUntil,
        position: position,
      );

  FakeAnnouncementEntry withPosition(int? newPosition) => FakeAnnouncementEntry(
    detail: detail,
    visibleFrom: visibleFrom,
    visibleUntil: visibleUntil,
    position: newPosition,
  );
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
       _entries = [...(seed ?? _defaultSeed)] {
    _lastId = _entries.fold(
      0,
      (max, e) => e.detail.id > max ? e.detail.id : max,
    );
    _lastImageId = _highestImageId;
  }

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
    // Una programada y una vencida, para ver la gestión con datos de prueba.
    FakeAnnouncementEntry(
      detail: AnnouncementDetail(
        id: 2,
        title: 'Horarios de la primavera',
        summary: 'Novedad programada de ejemplo.',
        text: '**Programada**: todavía no se ve para los socios.',
        publishedAt: DateTime.utc(2026, 11, 2),
        images: const [
          AnnouncementImage(
            id: 2,
            order: 0,
            url: 'https://example.invalid/novedad-programada',
          ),
        ],
      ),
      visibleFrom: DateTime.utc(2099, 1, 1, 3),
      visibleUntil: DateTime.utc(2099, 2, 1, 3),
    ),
    FakeAnnouncementEntry(
      detail: AnnouncementDetail(
        id: 3,
        title: 'Campaña de invierno',
        summary: 'Novedad vencida de ejemplo.',
        text: '**Vencida**: ya no se ve para los socios.',
        publishedAt: DateTime.utc(2026, 6, 1),
        images: const [
          AnnouncementImage(
            id: 3,
            order: 0,
            url: 'https://example.invalid/novedad-vencida',
          ),
        ],
      ),
      visibleUntil: DateTime.utc(2026, 7, 1, 3),
    ),
  ];

  static const _notFoundMessage = 'Anuncio no encontrado';

  final DateTime Function() _now;
  final List<FakeAnnouncementEntry> _entries;

  /// Los ids solo crecen: el de una novedad eliminada no se vuelve a usar.
  late int _lastId;

  /// Lo mismo para las imágenes que se suman al editar: como en el servidor,
  /// el id de una imagen quitada no se vuelve a usar.
  int _lastImageId = 0;

  int get _highestImageId => _entries
      .expand((e) => e.detail.images)
      .fold(0, (max, image) => math.max(max, image.id));

  /// Las novedades vigentes ahora: el listado, el detalle y el carrusel
  /// comparten esta regla y este reloj.
  Iterable<FakeAnnouncementEntry> get _visible {
    final now = _now();
    return _entries.where((entry) => entry.isVisibleAt(now));
  }

  int _indexOf(int id) => _entries.indexWhere((e) => e.detail.id == id);

  @override
  Future<void> publish(AnnouncementDraft draft) async {
    // El mismo 400 que responde el servidor.
    final visibilityError = draft.validateVisibility(_now());
    if (visibilityError != null) throw ApiException(visibilityError);
    _entries.insert(
      0,
      FakeAnnouncementEntry(
        detail: AnnouncementDetail(
          id: ++_lastId,
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

  /// Las mismas reglas y los mismos mensajes que el servidor, en este orden:
  /// título, resumen, existencia, imágenes y, al final, que quede texto o
  /// imágenes. Es todo o nada: nada se guarda hasta que todo pasó.
  @override
  Future<void> update(int id, AnnouncementEdit edit) async {
    final title = edit.title.trim();
    if (title.isEmpty || title.length > AnnouncementDraft.maxTitleLength) {
      throw const ApiException(
        'El título es obligatorio y admite hasta 160 caracteres',
      );
    }
    final summary = _blankToNull(edit.summary);
    if ((summary?.length ?? 0) > AnnouncementDraft.maxSummaryLength) {
      throw const ApiException('El resumen admite hasta 300 caracteres');
    }
    final index = _indexOf(id);
    if (index < 0) throw const ApiException(_notFoundMessage);
    final current = _entries[index].detail;
    final text = _blankToNull(edit.text);

    var images = current.images;
    var lastImageId = _lastImageId;
    final refs = edit.images;
    if (refs != null) {
      if (refs.length > AnnouncementImageUpload.maxCount) {
        throw const ApiException('La novedad admite hasta 5 imágenes');
      }
      final owned = {for (final image in current.images) image.id: image};
      final seen = <int>{};
      var nextId = math.max(_lastImageId, _highestImageId);
      final result = <AnnouncementImage>[];
      for (final ref in refs) {
        switch (ref) {
          case ExistingImageRef(id: final imageId):
            final existing = owned[imageId];
            if (existing == null) {
              throw ApiException(
                'La imagen $imageId no pertenece a esta novedad',
              );
            }
            if (!seen.add(imageId)) {
              throw ApiException('La imagen $imageId figura más de una vez');
            }
            result.add(
              AnnouncementImage(
                id: imageId,
                order: result.length,
                url: existing.url,
              ),
            );
          case NewImageRef(:final upload):
            final error = upload.validate();
            if (error != null) throw ApiException(error);
            result.add(
              AnnouncementImage(
                id: ++nextId,
                order: result.length,
                url: Uri.dataFromBytes(
                  upload.bytes,
                  mimeType: 'image/${upload.subtype}',
                ).toString(),
              ),
            );
        }
      }
      images = result;
      lastImageId = nextId;
    }
    if (text == null && images.isEmpty) {
      throw const ApiException(
        'La novedad debe tener texto o al menos una imagen',
      );
    }
    _lastImageId = lastImageId;
    _entries[index] = _entries[index].withDetail(
      AnnouncementDetail(
        id: current.id,
        title: title,
        summary: summary,
        text: text,
        publishedAt: current.publishedAt,
        images: List.unmodifiable(images),
      ),
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
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

  @override
  Future<AdminAnnouncementDetail> adminDetail(int id) async {
    // A diferencia de `detail`, no mira la vigencia: el administrador ve todo.
    final index = _indexOf(id);
    if (index < 0) throw const AnnouncementNotFoundException();
    final entry = _entries[index];
    return AdminAnnouncementDetail(
      id: entry.detail.id,
      title: entry.detail.title,
      summary: entry.detail.summary,
      text: entry.detail.text,
      publishedAt: entry.detail.publishedAt,
      visibleFrom: entry.visibleFrom,
      visibleUntil: entry.visibleUntil,
      status: entry.statusAt(_now()),
      position: entry.position,
      images: entry.detail.images,
    );
  }

  @override
  Future<List<AdminAnnouncement>> adminList() async {
    final now = _now();
    final sorted = [..._entries]
      ..sort((a, b) {
        final byDate = b.detail.publishedAt.compareTo(a.detail.publishedAt);
        return byDate != 0 ? byDate : b.detail.id.compareTo(a.detail.id);
      });
    return [
      for (final entry in sorted)
        AdminAnnouncement(
          id: entry.detail.id,
          title: entry.detail.title,
          publishedAt: entry.detail.publishedAt,
          visibleFrom: entry.visibleFrom,
          visibleUntil: entry.visibleUntil,
          status: entry.statusAt(now),
          position: entry.position,
        ),
    ];
  }

  @override
  Future<void> updateValidity(
    int id, {
    DateTime? from,
    required DateTime? until,
  }) async {
    // El mismo orden que el servidor: primero el fin, después la existencia.
    if (until == null) throw ApiException(AnnouncementDraft.endRequiredMessage);
    final index = _indexOf(id);
    if (index < 0) throw const ApiException(_notFoundMessage);
    final error = AnnouncementDraft.validateVisibilityRange(
      from,
      until,
      _now(),
    );
    if (error != null) throw ApiException(error);
    _entries[index] = _entries[index].withValidity(from, until);
  }

  @override
  Future<List<CarouselSlot>> adminCarousel() async {
    final chosen = [
      for (final entry in _entries)
        if (entry.position != null) entry,
    ]..sort((a, b) => a.position!.compareTo(b.position!));
    return [
      for (final entry in chosen)
        CarouselSlot(
          position: entry.position!,
          announcementId: entry.detail.id,
        ),
    ];
  }

  @override
  Future<List<CarouselSlot>> saveCarousel(List<CarouselSlot> slots) async {
    if (slots.length > AdminAnnouncement.maxCarouselSlots) {
      throw const ApiException('Selección inválida');
    }
    // Se valida todo antes de cambiar algo: un rechazo no deja la selección a
    // medias.
    final positions = <int>{};
    final ids = <int>{};
    for (final slot in slots) {
      if (slot.position < 1 ||
          slot.position > AdminAnnouncement.maxCarouselSlots ||
          slot.announcementId <= 0 ||
          !positions.add(slot.position) ||
          !ids.add(slot.announcementId)) {
        throw const ApiException('Posición o anuncio repetido o inválido');
      }
      if (_indexOf(slot.announcementId) < 0) {
        throw const ApiException(_notFoundMessage);
      }
    }
    final positionById = {for (final s in slots) s.announcementId: s.position};
    for (var i = 0; i < _entries.length; i++) {
      _entries[i] = _entries[i].withPosition(
        positionById[_entries[i].detail.id],
      );
    }
    return adminCarousel();
  }

  @override
  Future<void> delete(int id) async {
    final index = _indexOf(id);
    if (index < 0) throw const ApiException(_notFoundMessage);
    _entries.removeAt(index);
  }
}
