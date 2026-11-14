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
              NotificationFailure.other,
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
        expect({1, 2, 3}, contains(n.consultaId), reason: 'aviso ${n.id}');
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
