import 'package:agenda_medica/core/fakes/fake_notification_seed.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification.dart';
import 'package:agenda_medica/features/notificaciones/models/notification_query.dart';
import 'package:agenda_medica/features/notificaciones/repositories/fake_notification_repository.dart';
import 'package:agenda_medica/features/notificaciones/repositories/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification _n(int id, DateTime createdAt) => AppNotification(
  id: id,
  type: 'AGENDA',
  title: 'Consulta agendada',
  consultaId: 1,
  content: 'Aviso $id',
  createdAt: createdAt,
);

// Cinco avisos con un empate de instante (los ids 2 y 3) escritos fuera de
// orden a propósito. El orden esperado, escrito a mano, es 3, 2, 4, 1, 5.
final _seed = [
  _n(1, DateTime.utc(2026, 10, 1, 13)),
  _n(2, DateTime.utc(2026, 10, 3, 12)),
  _n(3, DateTime.utc(2026, 10, 3, 12)),
  _n(4, DateTime.utc(2026, 10, 2, 12)),
  _n(5, DateTime.utc(2026, 9, 30, 12)),
];

FakeNotificationRepository _repo([List<AppNotification>? seed]) =>
    FakeNotificationRepository(latency: Duration.zero, seed: seed ?? _seed);

List<int> _ids(Iterable<AppNotification> items) => [
  for (final n in items) n.id,
];

void main() {
  group('orden', () {
    test(
      'la más reciente primero y el id mayor primero en un empate',
      () async {
        final page = await _repo().list(const NotificationQuery());

        expect(_ids(page.items), [3, 2, 4, 1, 5]);
        expect(page.total, 5);
      },
    );

    test('el orden no depende del orden en que se cargaron', () async {
      final page = await _repo(_seed.reversed.toList())
          .list(const NotificationQuery());

      expect(_ids(page.items), [3, 2, 4, 1, 5]);
    });
  });

  group('paginación', () {
    test('la primera página trae size avisos y tiene siguiente', () async {
      final page = await _repo().list(
        const NotificationQuery(page: 0, size: 2),
      );

      expect(_ids(page.items), [3, 2]);
      expect(page.page, 0);
      expect(page.size, 2);
      expect(page.total, 5);
      expect(page.hasPrevious, isFalse);
      expect(page.hasNext, isTrue);
    });

    test('la página del medio tiene anterior y siguiente', () async {
      final page = await _repo().list(
        const NotificationQuery(page: 1, size: 2),
      );

      expect(_ids(page.items), [4, 1]);
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isTrue);
    });

    test('la última página trae lo que queda y no tiene siguiente', () async {
      final page = await _repo().list(
        const NotificationQuery(page: 2, size: 2),
      );

      expect(_ids(page.items), [5]);
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isFalse);
    });

    test('una última página incompleta no tiene siguiente', () async {
      final page = await _repo().list(
        const NotificationQuery(page: 1, size: 3),
      );

      expect(_ids(page.items), [1, 5]);
      expect(page.hasNext, isFalse);
    });

    test('con un total múltiplo exacto del tamaño la última página llena no '
        'tiene siguiente y la que sigue viene vacía', () async {
      final last = await _repo().list(
        const NotificationQuery(page: 0, size: 5),
      );

      expect(_ids(last.items), [3, 2, 4, 1, 5]);
      expect(last.hasPrevious, isFalse);
      expect(last.hasNext, isFalse);

      final beyond = await _repo().list(
        const NotificationQuery(page: 1, size: 5),
      );

      expect(beyond.items, isEmpty);
      expect(beyond.total, 5);
      expect(beyond.hasNext, isFalse);
    });

    test('una página más allá de la última viene vacía con el total', () async {
      final page = await _repo().list(
        const NotificationQuery(page: 3, size: 2),
      );

      expect(page.items, isEmpty);
      expect(page.total, 5);
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isFalse);
    });

    test('size 100 trae todos los avisos de una vez', () async {
      final page = await _repo().list(const NotificationQuery(size: 100));

      expect(_ids(page.items), [3, 2, 4, 1, 5]);
    });

    test('sin avisos la página está vacía', () async {
      final page = await _repo(const []).list(const NotificationQuery());

      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.hasPrevious, isFalse);
      expect(page.hasNext, isFalse);
    });
  });

  group('validación como el contrato', () {
    for (final (page, size) in [(0, 0), (0, 101), (-1, 20)]) {
      test('page $page y size $size son un 400', () async {
        await expectLater(
          _repo().list(NotificationQuery(page: page, size: size)),
          throwsA(
            isA<NotificationException>().having(
              (e) => e.failure,
              'failure',
              NotificationFailure.validation,
            ),
          ),
        );
      });
    }

    test('el mensaje de un size fuera de rango es el del servidor', () async {
      await expectLater(
        _repo().list(const NotificationQuery(size: 101)),
        throwsA(
          isA<NotificationException>().having(
            (e) => e.message,
            'message',
            'size debe estar entre 1 y 100',
          ),
        ),
      );
    });

    test('el mensaje de un page negativo es el del servidor', () async {
      await expectLater(
        _repo().list(const NotificationQuery(page: -1)),
        throwsA(
          isA<NotificationException>().having(
            (e) => e.message,
            'message',
            'page debe ser un entero mayor o igual a 0',
          ),
        ),
      );
    });
  });

  group('reglas del servidor', () {
    // 15/11/2026 12:00 en Uruguay.
    final now = DateTime.utc(2026, 11, 15, 15);

    FakeStoredNotification stored(
      int id,
      DateTime createdAt, {
      String owner = kFakeMemberCi,
      DateTime? scheduledFor,
      String type = 'AGENDA',
    }) => FakeStoredNotification(
      AppNotification(
        id: id,
        type: type,
        title: 'Aviso',
        consultaId: 1,
        content: 'Aviso $id',
        createdAt: createdAt,
      ),
      ownerCi: owner,
      scheduledFor: scheduledFor,
    );

    FakeNotificationRepository repo(
      List<FakeStoredNotification> items, {
      String ci = kFakeMemberCi,
      DateTime Function()? clock,
    }) => FakeNotificationRepository(
      latency: Duration.zero,
      stored: items,
      currentCi: ci,
      now: clock ?? () => now,
    );

    test('el socio solo ve los avisos propios', () async {
      final items = [
        stored(1, DateTime.utc(2026, 11, 10, 12)),
        stored(2, DateTime.utc(2026, 11, 12, 12), owner: kFakeOtherMemberCi),
        stored(3, DateTime.utc(2026, 11, 13, 12)),
        stored(4, DateTime.utc(2026, 11, 14, 12), owner: kFakeOtherMemberCi),
      ];

      final page = await repo(items).list(const NotificationQuery());

      expect(_ids(page.items), [3, 1]);
      expect(page.total, 2);
    });

    test('otro socio ve solo los suyos', () async {
      final items = [
        stored(1, DateTime.utc(2026, 11, 10, 12)),
        stored(2, DateTime.utc(2026, 11, 12, 12), owner: kFakeOtherMemberCi),
        stored(3, DateTime.utc(2026, 11, 13, 12)),
        stored(4, DateTime.utc(2026, 11, 14, 12), owner: kFakeOtherMemberCi),
      ];

      final page = await repo(
        items,
        ci: kFakeOtherMemberCi,
      ).list(const NotificationQuery());

      expect(_ids(page.items), [4, 2]);
      expect(page.total, 2);
    });

    test('un socio sin avisos ve la lista vacía', () async {
      final items = [stored(1, DateTime.utc(2026, 11, 10, 12))];

      final page = await repo(
        items,
        ci: '11111111',
      ).list(const NotificationQuery());

      expect(page.items, isEmpty);
      expect(page.total, 0);
    });

    test(
      'un recordatorio con fecha futura no aparece ni cuenta en el total',
      () async {
        final items = [
          stored(1, DateTime.utc(2026, 11, 10, 12)),
          stored(
            2,
            DateTime.utc(2026, 11, 14, 12),
            type: 'RECORDATORIO',
            scheduledFor: now.add(const Duration(hours: 1)),
          ),
          stored(
            3,
            DateTime.utc(2026, 11, 13, 12),
            type: 'RECORDATORIO',
            scheduledFor: now.subtract(const Duration(hours: 1)),
          ),
        ];

        final page = await repo(items).list(const NotificationQuery());

        expect(_ids(page.items), [3, 1]);
        expect(page.total, 2);
      },
    );

    test('el recordatorio aparece cuando llega su hora', () async {
      final scheduled = DateTime.utc(2026, 11, 16, 15);
      var clock = scheduled.subtract(const Duration(minutes: 1));
      final items = [
        stored(1, DateTime.utc(2026, 11, 10, 12)),
        stored(
          2,
          DateTime.utc(2026, 11, 14, 12),
          type: 'RECORDATORIO',
          scheduledFor: scheduled,
        ),
      ];
      final repository = repo(items, clock: () => clock);

      final before = await repository.list(const NotificationQuery());
      clock = scheduled;
      final atTheHour = await repository.list(const NotificationQuery());

      expect(_ids(before.items), [1]);
      expect(_ids(atTheHour.items), [2, 1]);
    });

    test('el total de la paginación no cuenta lo que no se lista', () async {
      final items = [
        for (var i = 1; i <= 25; i++)
          stored(i, DateTime.utc(2026, 11, 1).add(Duration(hours: i))),
        for (var i = 101; i <= 103; i++)
          stored(
            i,
            DateTime.utc(2026, 11, 14, i - 100),
            owner: kFakeOtherMemberCi,
          ),
        stored(
          201,
          DateTime.utc(2026, 11, 14, 12),
          type: 'RECORDATORIO',
          scheduledFor: now.add(const Duration(days: 1)),
        ),
      ];

      final last = await repo(items)
          .list(const NotificationQuery(page: 2, size: 10));

      expect(last.total, 25);
      expect(_ids(last.items), [5, 4, 3, 2, 1]);
      expect(last.hasNext, isFalse);
    });
  });

  group('semilla relativa a la hora actual', () {
    // 15/11/2026 12:00 en Uruguay.
    final now = DateTime.utc(2026, 11, 15, 15);
    late List<FakeStoredNotification> seed;

    setUp(() => seed = fakeNotificationSeed(now));

    test('trae avisos de otro socio y recordatorios futuros para probar las '
        'reglas', () {
      expect(seed.where((s) => s.ownerCi == kFakeOtherMemberCi), hasLength(3));
      expect(
        seed.where(
          (s) => s.scheduledFor != null && s.scheduledFor!.isAfter(now),
        ),
        hasLength(2),
      );
    });

    test('la socia de prueba ve 26 avisos y ninguno de los ocultos', () async {
      final page = await FakeNotificationRepository(
        latency: Duration.zero,
        now: () => now,
      ).list(const NotificationQuery(size: 100));

      expect(page.total, 26);
      expect(page.items, hasLength(26));
    });

    test('todos los avisos visibles son del pasado y el más nuevo es de las '
        'últimas 24 horas', () async {
      final page = await FakeNotificationRepository(
        latency: Duration.zero,
        now: () => now,
      ).list(const NotificationQuery(size: 100));

      for (final n in page.items) {
        expect(n.createdAt.isAfter(now), isFalse, reason: 'aviso ${n.id}');
      }
      expect(
        page.items.first.createdAt.isAfter(
          now.subtract(const Duration(hours: 24)),
        ),
        isTrue,
      );
      expect(
        page.items.last.createdAt.isAfter(
          now.subtract(const Duration(days: 120)),
        ),
        isTrue,
      );
    });

    test('los avisos se corren con la hora: con otro "ahora" siguen siendo '
        'del pasado', () async {
      final later = DateTime.utc(2027, 3, 1, 15);
      final page = await FakeNotificationRepository(
        latency: Duration.zero,
        now: () => later,
      ).list(const NotificationQuery(size: 100));

      for (final n in page.items) {
        expect(n.createdAt.isAfter(later), isFalse, reason: 'aviso ${n.id}');
      }
    });
  });

  group('semilla por defecto', () {
    late List<AppNotification> all;

    setUp(() async {
      final page = await FakeNotificationRepository(latency: Duration.zero)
          .list(const NotificationQuery(size: 100));
      all = page.items;
    });

    test('tiene al menos 25 avisos', () {
      expect(all.length, greaterThanOrEqualTo(25));
    });

    test('incluye los cinco tipos', () {
      expect(
        {for (final n in all) n.type},
        {
          'AGENDA',
          'CANCELACION',
          'SUSPENSION',
          'HISTORIA_ACTUALIZADA',
          'RECORDATORIO',
        },
      );
    });

    test('todos tienen título y contenido y cuelgan de una consulta de la '
        'semilla del socio', () {
      for (final n in all) {
        expect(n.title, isNotEmpty, reason: 'aviso ${n.id}');
        expect(n.content, isNotEmpty, reason: 'aviso ${n.id}');
        // Los de suspensión van sin consulta: el Fake no tiene una cancelada
        // por la institución a la que enlazarlos.
        if (n.type == 'SUSPENSION') {
          expect(n.consultaId, isNull, reason: 'aviso ${n.id}');
        } else {
          expect({1, 2, 3}, contains(n.consultaId), reason: 'aviso ${n.id}');
        }
      }
    });

    test('los ids no se repiten y vienen ordenados como el contrato', () {
      expect(all.map((n) => n.id).toSet().length, all.length);
      for (var i = 1; i < all.length; i++) {
        final previous = all[i - 1];
        final current = all[i];
        final newer = previous.createdAt.isAfter(current.createdAt);
        final tieBreak =
            previous.createdAt == current.createdAt && previous.id > current.id;
        expect(newer || tieBreak, isTrue, reason: 'posición $i');
      }
    });

    test('la semilla tiene al menos un empate de instante', () {
      final instants = [for (final n in all) n.createdAt];
      expect(instants.toSet().length, lessThan(instants.length));
    });

    test('con size 10 hay tres páginas (25 o 26 avisos)', () async {
      final repo = FakeNotificationRepository(latency: Duration.zero);

      final last = await repo.list(const NotificationQuery(page: 2, size: 10));

      expect(last.items, isNotEmpty);
      expect(last.hasNext, isFalse);
    });
  });
}
