import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/repositories/announcements_repository.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// "Ahora" fijo: 14/11/2026 12:00 en Uruguay (15:00 UTC).
final _now = DateTime.utc(2026, 11, 14, 15);

const _endMessage =
    'La fecha de fin es obligatoria y debe ser posterior al inicio';
const _notFoundMessage = 'Anuncio no encontrado';

FakeAnnouncementEntry _entry(
  int id, {
  int? position,
  DateTime? from,
  DateTime? until,
  DateTime? published,
}) => FakeAnnouncementEntry(
  detail: AnnouncementDetail(
    id: id,
    title: 'Novedad $id',
    text: 'Texto $id',
    publishedAt: published ?? DateTime.utc(2026, 11, 1),
  ),
  visibleFrom: from,
  visibleUntil: until,
  position: position,
);

FakeAnnouncementsRepository _fake(List<FakeAnnouncementEntry> seed) =>
    FakeAnnouncementsRepository(now: () => _now, seed: seed);

Matcher _failsWith(String message) =>
    throwsA(isA<ApiException>().having((e) => e.message, 'message', message));

Future<List<int>> _carouselIds(FakeAnnouncementsRepository repo) async =>
    (await repo.carousel()).map((a) => a.id).toList();

Future<Map<int, int>> _selection(FakeAnnouncementsRepository repo) async => {
  for (final s in await repo.adminCarousel()) s.position: s.announcementId,
};

void main() {
  group('listado de administración', () {
    test(
      'trae todas con su estado calculado con el reloj inyectable',
      () async {
        final repo = _fake([
          _entry(1, from: DateTime.utc(2026, 11, 15, 3)),
          _entry(2, until: DateTime.utc(2026, 11, 14, 14, 59)),
          _entry(3, until: DateTime.utc(2026, 12, 1, 3)),
          _entry(4),
        ]);

        final items = await repo.adminList();

        expect(
          {for (final i in items) i.id: i.status},
          {
            1: AnnouncementStatus.scheduled,
            2: AnnouncementStatus.expired,
            3: AnnouncementStatus.active,
            4: AnnouncementStatus.active,
          },
        );
      },
    );

    test(
      'el inicio exacto ya es vigente y el fin exacto ya es vencido',
      () async {
        final repo = _fake([_entry(1, from: _now), _entry(2, until: _now)]);

        final items = await repo.adminList();

        expect(
          {for (final i in items) i.id: i.status},
          {1: AnnouncementStatus.active, 2: AnnouncementStatus.expired},
        );
      },
    );

    test('trae la posición del carrusel y la vigencia guardada', () async {
      final until = DateTime.utc(2026, 12, 1, 3);
      final repo = _fake([_entry(1, position: 4, until: until), _entry(2)]);

      final items = await repo.adminList();

      expect(items.firstWhere((i) => i.id == 1).position, 4);
      expect(items.firstWhere((i) => i.id == 1).visibleUntil, until);
      expect(items.firstWhere((i) => i.id == 2).position, isNull);
    });

    test(
      'ordena por fecha de publicación y luego por id, descendente',
      () async {
        final repo = _fake([
          _entry(1, published: DateTime.utc(2026, 11, 1)),
          _entry(2, published: DateTime.utc(2026, 11, 5)),
          _entry(3, published: DateTime.utc(2026, 11, 5)),
        ]);

        expect((await repo.adminList()).map((i) => i.id), [3, 2, 1]);
      },
    );
  });

  group('cambiar la vigencia', () {
    final until = DateTime.utc(2026, 12, 1, 3);

    test('sin fin responde el mismo 400', () async {
      final repo = _fake([_entry(1)]);

      await expectLater(
        repo.updateValidity(1, until: null),
        _failsWith(_endMessage),
      );
    });

    test('con fin igual al inicio responde el mismo 400', () async {
      final repo = _fake([_entry(1)]);

      await expectLater(
        repo.updateValidity(1, from: until, until: until),
        _failsWith(_endMessage),
      );
    });

    test('con fin anterior al inicio responde el mismo 400', () async {
      final repo = _fake([_entry(1)]);

      await expectLater(
        repo.updateValidity(
          1,
          from: DateTime.utc(2026, 12, 2, 3),
          until: DateTime.utc(2026, 12, 1, 3),
        ),
        _failsWith(_endMessage),
      );
    });

    test('sin inicio y con fin pasado responde el mismo 400', () async {
      final repo = _fake([_entry(1)]);

      await expectLater(
        repo.updateValidity(1, until: DateTime.utc(2026, 11, 14, 14, 59)),
        _failsWith(_endMessage),
      );
    });

    test('una validación rechazada no cambia nada', () async {
      final repo = _fake([_entry(1, until: until)]);

      await expectLater(
        repo.updateValidity(1, until: null),
        throwsA(isA<ApiException>()),
      );

      expect((await repo.adminList()).single.visibleUntil, until);
    });

    test('una novedad que no existe responde 404', () async {
      final repo = _fake([_entry(1)]);

      await expectLater(
        repo.updateValidity(99, until: until),
        _failsWith(_notFoundMessage),
      );
    });

    test('guarda la vigencia y recalcula el estado', () async {
      final repo = _fake([
        _entry(1, until: DateTime.utc(2026, 11, 14, 14, 59)),
      ]);
      expect(
        (await repo.adminList()).single.status,
        AnnouncementStatus.expired,
      );
      expect((await repo.list()).items, isEmpty);

      await repo.updateValidity(1, until: until);

      final item = (await repo.adminList()).single;
      expect(item.status, AnnouncementStatus.active);
      expect(item.visibleUntil, until);
      expect(item.visibleFrom, isNull);
      expect((await repo.list()).items.single.id, 1);
    });

    test('programar una vigente la saca del listado de los socios', () async {
      final repo = _fake([_entry(1)]);

      await repo.updateValidity(
        1,
        from: DateTime.utc(2026, 11, 20, 3),
        until: DateTime.utc(2026, 11, 21, 3),
      );

      expect(
        (await repo.adminList()).single.status,
        AnnouncementStatus.scheduled,
      );
      expect((await repo.list()).items, isEmpty);
    });
  });

  group('carrusel del administrador', () {
    test('guardar con huecos (posiciones 1 y 3) los conserva', () async {
      final repo = _fake([_entry(10), _entry(20), _entry(30)]);

      final saved = await repo.saveCarousel(const [
        CarouselSlot(position: 1, announcementId: 10),
        CarouselSlot(position: 3, announcementId: 30),
      ]);

      expect(saved.map((s) => (s.position, s.announcementId)), [
        (1, 10),
        (3, 30),
      ]);
      expect(await _selection(repo), {1: 10, 3: 30});
    });

    test('lo guardado cambia lo que muestra el carrusel del Inicio', () async {
      final repo = _fake([_entry(10, position: 1), _entry(20), _entry(30)]);
      expect(await _carouselIds(repo), [10]);

      await repo.saveCarousel(const [
        CarouselSlot(position: 3, announcementId: 20),
        CarouselSlot(position: 1, announcementId: 30),
      ]);

      expect(await _carouselIds(repo), [30, 20]);
    });

    test('guardar reemplaza toda la selección anterior', () async {
      final repo = _fake([
        _entry(10, position: 1),
        _entry(20, position: 2),
        _entry(30),
      ]);

      await repo.saveCarousel(const [
        CarouselSlot(position: 5, announcementId: 30),
      ]);

      expect(await _selection(repo), {5: 30});
      expect(
        (await repo.adminList()).firstWhere((i) => i.id == 10).position,
        isNull,
      );
    });

    test('guardar una selección vacía vacía el carrusel', () async {
      final repo = _fake([_entry(10, position: 1)]);

      await repo.saveCarousel(const []);

      expect(await _selection(repo), isEmpty);
      expect(await _carouselIds(repo), isEmpty);
    });

    test('una novedad no vigente puede elegirse pero no se muestra', () async {
      final repo = _fake([
        _entry(10),
        _entry(20, until: DateTime.utc(2026, 11, 14, 14, 59)),
      ]);

      await repo.saveCarousel(const [
        CarouselSlot(position: 1, announcementId: 20),
        CarouselSlot(position: 2, announcementId: 10),
      ]);

      expect(await _selection(repo), {1: 20, 2: 10});
      expect(await _carouselIds(repo), [10]);
    });

    for (final (description, slots) in [
      (
        'más de cinco posiciones',
        [
          for (var i = 1; i <= 6; i++)
            CarouselSlot(position: i, announcementId: i * 10),
        ],
      ),
      (
        'una posición repetida',
        const [
          CarouselSlot(position: 1, announcementId: 10),
          CarouselSlot(position: 1, announcementId: 20),
        ],
      ),
      (
        'una novedad repetida',
        const [
          CarouselSlot(position: 1, announcementId: 10),
          CarouselSlot(position: 2, announcementId: 10),
        ],
      ),
      ('la posición 0', const [CarouselSlot(position: 0, announcementId: 10)]),
      ('la posición 6', const [CarouselSlot(position: 6, announcementId: 10)]),
    ]) {
      test('rechaza $description con 400 y no cambia la selección', () async {
        final repo = _fake(
          [for (var i = 1; i <= 6; i++) _entry(i * 10)]
            ..[0] = _entry(10, position: 2),
        );

        await expectLater(
          repo.saveCarousel(slots),
          throwsA(isA<ApiException>()),
        );

        expect(await _selection(repo), {2: 10});
      });
    }

    test('una novedad que no existe responde 404 y no cambia nada', () async {
      final repo = _fake([_entry(10, position: 1), _entry(20)]);

      await expectLater(
        repo.saveCarousel(const [
          CarouselSlot(position: 2, announcementId: 20),
          CarouselSlot(position: 3, announcementId: 99),
        ]),
        _failsWith(_notFoundMessage),
      );

      expect(await _selection(repo), {1: 10});
    });
  });

  group('eliminar', () {
    test(
      'borra de verdad: listado, detalle, administración y carrusel',
      () async {
        final repo = _fake([_entry(10, position: 1), _entry(20, position: 2)]);

        await repo.delete(10);

        expect((await repo.adminList()).map((i) => i.id), [20]);
        expect((await repo.list()).items.map((i) => i.id), [20]);
        await expectLater(
          repo.detail(10),
          throwsA(isA<AnnouncementNotFoundException>()),
        );
        expect(await _carouselIds(repo), [20]);
        expect(await _selection(repo), {2: 20});
      },
    );

    test('eliminar una que no existe responde 404', () async {
      final repo = _fake([_entry(10)]);

      await expectLater(repo.delete(99), _failsWith(_notFoundMessage));
    });

    test('eliminar dos veces: la segunda responde 404', () async {
      final repo = _fake([_entry(10)]);
      await repo.delete(10);

      await expectLater(repo.delete(10), _failsWith(_notFoundMessage));
    });

    test('un id nuevo no reutiliza el de una eliminada', () async {
      final repo = _fake([_entry(10), _entry(20)]);
      await repo.delete(20);

      await repo.publish(
        AnnouncementDraft(
          title: 'Nueva',
          text: 'Texto',
          visibleUntil: DateTime.utc(2099, 1, 1, 3),
        ),
      );

      // Los ids solo crecen: el 20 eliminado no se vuelve a usar.
      expect((await repo.adminList()).map((i) => i.id).toSet(), {21, 10});
    });
  });
}
