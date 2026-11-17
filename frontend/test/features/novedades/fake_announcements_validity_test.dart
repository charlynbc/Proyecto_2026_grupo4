import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/repositories/announcements_repository.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// "Ahora" fijo: 14/11/2026 12:00 en Uruguay (15:00 UTC).
final _now = DateTime.utc(2026, 11, 14, 15);

FakeAnnouncementEntry _entry(int id, {DateTime? from, DateTime? until}) =>
    FakeAnnouncementEntry(
      detail: AnnouncementDetail(
        id: id,
        title: 'Novedad $id',
        text: 'Texto $id',
        publishedAt: DateTime.utc(2026, 11, 1),
      ),
      visibleFrom: from,
      visibleUntil: until,
    );

FakeAnnouncementsRepository _fake(List<FakeAnnouncementEntry> seed) =>
    FakeAnnouncementsRepository(now: () => _now, seed: seed);

Future<List<int>> _listedIds(FakeAnnouncementsRepository repo) async =>
    (await repo.list()).items.map((item) => item.id).toList();

Matcher get _notFound => throwsA(isA<AnnouncementNotFoundException>());

void main() {
  test(
    'un anuncio programado no aparece en el listado ni en el detalle',
    () async {
      final repo = _fake([
        _entry(10, from: DateTime.utc(2026, 11, 15, 3)),
        _entry(11),
      ]);

      expect(await _listedIds(repo), [11]);
      await expectLater(repo.detail(10), _notFound);
    },
  );

  test(
    'un anuncio vencido no aparece en el listado ni en el detalle',
    () async {
      final repo = _fake([
        _entry(20, until: DateTime.utc(2026, 11, 14, 14, 59)),
        _entry(21),
      ]);

      expect(await _listedIds(repo), [21]);
      await expectLater(repo.detail(20), _notFound);
    },
  );

  test('un anuncio vigente aparece en el listado y en el detalle', () async {
    final repo = _fake([
      _entry(
        30,
        from: DateTime.utc(2026, 11, 14, 14, 59),
        until: DateTime.utc(2026, 11, 14, 15, 1),
      ),
    ]);

    expect(await _listedIds(repo), [30]);
    expect((await repo.detail(30)).title, 'Novedad 30');
  });

  test('en el minuto exacto del inicio ya aparece', () async {
    final repo = _fake([_entry(40, from: _now)]);

    expect(await _listedIds(repo), [40]);
    expect((await repo.detail(40)).id, 40);
  });

  test('en el minuto exacto del fin ya no aparece', () async {
    final repo = _fake([_entry(50, until: _now)]);

    expect(await _listedIds(repo), isEmpty);
    await expectLater(repo.detail(50), _notFound);
  });

  test('sin inicio aparece desde la publicacion', () async {
    final repo = _fake([_entry(60, until: DateTime.utc(2026, 11, 20, 3))]);

    expect(await _listedIds(repo), [60]);
    expect((await repo.detail(60)).id, 60);
  });

  test('la paginacion y el total cuentan solo los vigentes', () async {
    final repo = _fake([
      for (var id = 1; id <= 12; id++) _entry(id),
      _entry(90, from: DateTime.utc(2026, 11, 15, 3)),
      _entry(91, until: DateTime.utc(2026, 11, 14, 14, 59)),
      _entry(92, until: _now),
    ]);

    final first = await repo.list();
    final second = await repo.list(page: 1);

    expect(first.items.map((item) => item.id), [
      for (var i = 1; i <= 10; i++) i,
    ]);
    expect(first.total, 12);
    expect(second.items.map((item) => item.id), [11, 12]);
    expect(second.total, 12);
  });

  test('lo publicado con inicio de manana no se ve hoy', () async {
    final repo = FakeAnnouncementsRepository(now: () => _now);

    // 15/11/2026 00:00 a 23:59 en Uruguay, con hoy 14/11.
    await repo.publish(
      AnnouncementDraft(
        title: 'Programada',
        text: 'Texto',
        visibleFrom: DateTime.utc(2026, 11, 15, 3),
        visibleUntil: DateTime.utc(2026, 11, 16, 2, 59),
      ),
    );

    expect(await _listedIds(repo), [1]);
    await expectLater(repo.detail(2), _notFound);
  });
}
