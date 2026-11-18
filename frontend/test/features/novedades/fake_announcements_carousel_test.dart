import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// "Ahora" fijo: 14/11/2026 12:00 en Uruguay (15:00 UTC).
final _now = DateTime.utc(2026, 11, 14, 15);

FakeAnnouncementEntry _entry(
  int id, {
  int? position,
  DateTime? from,
  DateTime? until,
  DateTime? published,
  List<AnnouncementImage> images = const [],
}) => FakeAnnouncementEntry(
  detail: AnnouncementDetail(
    id: id,
    title: 'Novedad $id',
    text: 'Texto $id',
    publishedAt: published ?? DateTime.utc(2026, 11, 1),
    images: images,
  ),
  visibleFrom: from,
  visibleUntil: until,
  position: position,
);

FakeAnnouncementsRepository _fake(List<FakeAnnouncementEntry> seed) =>
    FakeAnnouncementsRepository(now: () => _now, seed: seed);

Future<List<int>> _ids(FakeAnnouncementsRepository repo) async =>
    (await repo.carousel()).map((item) => item.id).toList();

void main() {
  test('con huecos en las posiciones 1 y 3 no rellena la 2', () async {
    final repo = _fake([
      _entry(10, position: 3, until: DateTime.utc(2026, 12, 1)),
      _entry(11, position: 1),
      _entry(12),
    ]);

    expect(await _ids(repo), [11, 10]);
  });

  test('una sola novedad con posición', () async {
    final repo = _fake([_entry(10, position: 4), _entry(11)]);

    expect(await _ids(repo), [10]);
  });

  test('sin ninguna posición el carrusel está vacío', () async {
    final repo = _fake([_entry(10), _entry(11)]);

    expect(await _ids(repo), isEmpty);
  });

  test('ordena por posición y no por fecha de publicación', () async {
    final repo = _fake([
      _entry(20, position: 2, published: DateTime.utc(2026, 11, 12)),
      _entry(21, position: 1, published: DateTime.utc(2026, 10, 1)),
      _entry(22, position: 3, published: DateTime.utc(2026, 11, 13)),
    ]);

    expect(await _ids(repo), [21, 20, 22]);
  });

  test('un anuncio programado con posición no aparece', () async {
    final repo = _fake([
      _entry(30, position: 1, from: DateTime.utc(2026, 12, 1, 3)),
      _entry(31, position: 2),
    ]);

    expect(await _ids(repo), [31]);
  });

  test('un anuncio que empieza justo ahora ya aparece', () async {
    final repo = _fake([_entry(32, position: 1, from: _now)]);

    expect(await _ids(repo), [32]);
  });

  test('un anuncio vencido con posición no aparece', () async {
    final repo = _fake([
      _entry(40, position: 1, until: DateTime.utc(2026, 11, 14, 14, 59)),
      _entry(41, position: 2, until: DateTime.utc(2026, 11, 14, 15, 1)),
    ]);

    expect(await _ids(repo), [41]);
  });

  test('un anuncio cuyo fin es justo ahora ya no aparece', () async {
    final repo = _fake([_entry(42, position: 1, until: _now)]);

    expect(await _ids(repo), isEmpty);
  });

  test('la portada es la primera imagen por orden', () async {
    final repo = _fake([
      _entry(
        50,
        position: 1,
        images: const [
          AnnouncementImage(id: 502, order: 2, url: 'https://example.org/c'),
          AnnouncementImage(id: 501, order: 0, url: 'https://example.org/a'),
          AnnouncementImage(id: 503, order: 1, url: 'https://example.org/b'),
        ],
      ),
      _entry(51, position: 2),
    ]);

    final items = await repo.carousel();

    expect(items[0].coverUrl, 'https://example.org/a');
    expect(items[0].coverImageId, 501);
    expect(items[1].coverUrl, isNull);
    expect(items[1].coverImageId, isNull);
  });

  test(
    'sin datos propios trae la novedad de ejemplo en la posición 1',
    () async {
      final repo = FakeAnnouncementsRepository(now: () => _now);

      expect(await _ids(repo), [1]);
    },
  );

  test('lo publicado no entra al carrusel porque no tiene posición', () async {
    final repo = FakeAnnouncementsRepository(now: () => _now);
    await repo.publish(
      AnnouncementDraft(
        title: 'Nueva',
        text: 'Texto',
        visibleUntil: DateTime.utc(2099, 1, 1, 3),
      ),
    );

    expect(await _ids(repo), [1]);
    final page = await repo.list();
    expect(page.items.first.title, 'Nueva');
  });
}
