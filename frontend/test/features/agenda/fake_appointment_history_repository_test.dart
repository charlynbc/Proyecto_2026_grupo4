import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_agenda_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_appointment_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Hoy fijo (clave de día de Uruguay): 24/10/2026. La semilla cae en
// 05/11/2026 (+12), 13/10/2026 (-11) y 23/09/2026 (-31).
final _today = DateTime.utc(2026, 10, 24);

FakeAppointmentHistoryRepository _repo({DateTime? today}) {
  final db = FakeDatabase(today: today ?? _today, admin: FakeAdminDatabase());
  return FakeAppointmentHistoryRepository(db, latency: Duration.zero);
}

List<int> _ids(Iterable<dynamic> items) => [for (final a in items) a.id as int];

void main() {
  group('semilla de la socia', () {
    test('trae tres consultas, la más reciente primero', () async {
      final page = await _repo().list(const AppointmentHistoryQuery());

      expect(page.total, 3);
      expect(_ids(page.items), [1, 2, 3]);
      expect(
        [for (final a in page.items) a.status],
        ['AGENDADA', 'CANCELADA_SOCIO', 'ATENDIDA'],
      );
    });

    test('la agendada es de Dermatología, dentro de 12 días', () async {
      final a = await _repo().get(1);

      expect(a.status, 'AGENDADA');
      expect(a.specialty.name, 'Dermatología');
      expect(a.specialty.id, 3);
      expect(a.date, DateTime.utc(2026, 11, 5));
      expect(a.doctor.lastName, 'Acosta');
      expect(a.cancelledAt, isNull);
      expect(a.cancellationReason, isNull);
    });

    test('la cancelada es de Medicina General, hace 11 días', () async {
      final a = await _repo().get(2);

      expect(a.status, 'CANCELADA_SOCIO');
      expect(a.specialty.name, 'Medicina General');
      expect(a.specialty.id, 1);
      expect(a.date, DateTime.utc(2026, 10, 13));
      expect(a.cancelledAt, isNotNull);
      expect(a.cancellationReason, isNull);
    });

    test('la atendida es de Medicina General, hace 31 días', () async {
      final a = await _repo().get(3);

      expect(a.status, 'ATENDIDA');
      expect(a.specialty.name, 'Medicina General');
      expect(a.date, DateTime.utc(2026, 9, 23));
      expect(a.cancelledAt, isNull);
    });

    test('las fechas se mueven con el día de hoy', () async {
      final repo = _repo(today: DateTime.utc(2026, 12, 1));

      expect((await repo.get(1)).date, DateTime.utc(2026, 12, 13));
      expect((await repo.get(2)).date, DateTime.utc(2026, 11, 20));
      expect((await repo.get(3)).date, DateTime.utc(2026, 10, 31));
    });
  });

  group('filtros', () {
    test('por estado', () async {
      final page = await _repo().list(
        const AppointmentHistoryQuery(status: 'CANCELADA_SOCIO'),
      );

      expect(_ids(page.items), [2]);
      expect(page.total, 1);
    });

    test('por especialidad', () async {
      final page = await _repo().list(
        const AppointmentHistoryQuery(specialtyId: 3),
      );

      expect(_ids(page.items), [1]);
      expect(page.total, 1);
    });

    test('por médico, por su id', () async {
      final repo = _repo();

      final acosta = await repo.list(
        const AppointmentHistoryQuery(doctorId: 3),
      );
      final mendez = await repo.list(
        const AppointmentHistoryQuery(doctorId: 1),
      );

      expect(_ids(acosta.items), [1]);
      expect(_ids(mendez.items), [2, 3]);
    });

    test('por rango de fechas, con los dos extremos incluidos', () async {
      final repo = _repo();

      final october = await repo.list(
        AppointmentHistoryQuery(
          from: DateTime.utc(2026, 10, 1),
          to: DateTime.utc(2026, 10, 31),
        ),
      );
      final oneDay = await repo.list(
        AppointmentHistoryQuery(
          from: DateTime.utc(2026, 10, 13),
          to: DateTime.utc(2026, 10, 13),
        ),
      );

      expect(_ids(october.items), [2]);
      expect(_ids(oneDay.items), [2]);
    });

    test('sin coincidencias devuelve una página vacía, no un error', () async {
      final page = await _repo().list(
        const AppointmentHistoryQuery(status: 'NO_ASISTIO'),
      );

      expect(page.items, isEmpty);
      expect(page.total, 0);
    });
  });

  group('orden', () {
    test('por defecto es por fecha, la más reciente primero', () async {
      const query = AppointmentHistoryQuery();

      expect(query.order, AppointmentHistoryOrder.date);
      expect(query.direction, AppointmentHistoryDirection.descending);
      expect(_ids((await _repo().list(query)).items), [1, 2, 3]);
    });

    test('por fecha ascendente', () async {
      final page = await _repo().list(
        const AppointmentHistoryQuery(
          direction: AppointmentHistoryDirection.ascending,
        ),
      );

      expect(_ids(page.items), [3, 2, 1]);
    });

    test('por especialidad ascendente, con la fecha como desempate', () async {
      final page = await _repo().list(
        const AppointmentHistoryQuery(
          order: AppointmentHistoryOrder.specialty,
          direction: AppointmentHistoryDirection.ascending,
        ),
      );

      // Dermatología, y después Medicina General de la más vieja a la nueva.
      expect(_ids(page.items), [1, 3, 2]);
    });

    test('por especialidad descendente', () async {
      final page = await _repo().list(
        const AppointmentHistoryQuery(
          order: AppointmentHistoryOrder.specialty,
          direction: AppointmentHistoryDirection.descending,
        ),
      );

      expect(_ids(page.items), [2, 3, 1]);
    });
  });

  group('paginación', () {
    test(
      'el tamaño de página por defecto es 20, como en la consulta real',
      () async {
        final page = await _repo().list(const AppointmentHistoryQuery());

        expect(page.size, 20);
        expect(page.page, 0);
      },
    );

    test('pagina de a dos', () async {
      final repo = _repo();

      final first = await repo.list(const AppointmentHistoryQuery(size: 2));
      final second = await repo.list(
        const AppointmentHistoryQuery(page: 1, size: 2),
      );

      expect(_ids(first.items), [1, 2]);
      expect(first.total, 3);
      expect(first.hasNext, isTrue);
      expect(first.hasPrevious, isFalse);
      expect(_ids(second.items), [3]);
      expect(second.page, 1);
      expect(second.size, 2);
      expect(second.total, 3);
      expect(second.hasNext, isFalse);
      expect(second.hasPrevious, isTrue);
    });

    test(
      'una página más allá de la última viene vacía, con el total',
      () async {
        final page = await _repo().list(
          const AppointmentHistoryQuery(page: 5, size: 2),
        );

        expect(page.items, isEmpty);
        expect(page.total, 3);
      },
    );
  });

  group('detalle', () {
    test('devuelve la consulta por su id', () async {
      expect((await _repo().get(3)).status, 'ATENDIDA');
    });

    for (final id in [999, 0, -1]) {
      test(
        'el id $id inexistente tira AppointmentHistoryException notFound',
        () {
          expect(
            _repo().get(id),
            throwsA(
              isA<AppointmentHistoryException>().having(
                (e) => e.failure,
                'failure',
                AppointmentHistoryFailure.notFound,
              ),
            ),
          );
        },
      );
    }
  });

  test('lo que se agenda en el fake aparece en el historial', () async {
    final admin = FakeAdminDatabase();
    final db = FakeDatabase(today: _today, admin: admin);
    final agenda = FakeAgendaRepository(
      db,
      admin,
      latency: Duration.zero,
      clock: () => DateTime.utc(2026, 10, 24, 15),
    );
    final history = FakeAppointmentHistoryRepository(
      db,
      latency: Duration.zero,
    );
    // Medicina General es la especialidad 1 y no pide pase.
    final numbers = await agenda.listAvailability(
      const AvailabilityQuery(specialtyId: 1),
    );
    expect(numbers, isNotEmpty);

    final booked = await agenda.book(numberId: numbers.last.numberId);
    final page = await history.list(const AppointmentHistoryQuery());

    expect(booked.id, 4);
    expect(page.total, 4);
    expect(page.items.first.id, 4);
    expect(page.items.first.status, 'AGENDADA');
    expect(page.items.first.specialty.name, 'Medicina General');
    expect((await history.get(4)).id, 4);
  });
}
