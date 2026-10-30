import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/validators/uruguayan_ci_validator.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _today = DateTime.utc(2026, 10, 26);

FakeScheduleRepository _repository() =>
    FakeScheduleRepository(latency: Duration.zero, today: _today);

ScheduleFilters _filters() => ScheduleFilters(date: _today);

List<int> _ids(SchedulePage page) => [
  for (final entry in page.items) entry.appointmentId,
];

void main() {
  group('sin filtros', () {
    test('devuelve las cinco consultas de hoy, por fecha y hora', () async {
      final page = await _repository().search(_filters());

      expect(_ids(page), [9001, 9002, 9003, 9004, 9005]);
      expect(page.total, 5);
      expect(page.page, 0);
      expect(page.size, 20);
    });

    test('todas son de la fecha de hoy', () async {
      final page = await _repository().search(_filters());

      for (final entry in page.items) {
        expect(entry.date, _today);
      }
    });

    test('dos tienen llegada y una de ellas está NO_ATENDIDA', () async {
      final page = await _repository().search(_filters());
      final arrived = page.items.where((e) => e.arrivedAt != null).toList();

      expect(arrived, hasLength(2));
      expect(arrived.where((e) => e.status == 'NO_ATENDIDA'), hasLength(1));
    });

    test('las llegadas son de hoy, con -03:00', () async {
      final page = await _repository().search(_filters());

      // 9001 llegó a las 08:55 y 9002 a las 08:40, hora de Uruguay.
      expect(page.items[0].arrivedAt, DateTime.utc(2026, 10, 26, 11, 55));
      expect(page.items[0].arrivalTime, '08:55');
      expect(page.items[1].arrivedAt, DateTime.utc(2026, 10, 26, 11, 40));
      expect(page.items[1].arrivalTime, '08:40');
    });

    test('los estados son variados y todos válidos', () async {
      final page = await _repository().search(_filters());

      expect(
        [for (final e in page.items) e.status],
        ['AGENDADA', 'NO_ATENDIDA', 'ATENDIDA', 'AGENDADA', 'CANCELADA_SOCIO'],
      );
    });
  });

  group('datos', () {
    test('son cinco socios distintos, con Ana, Carlos y Luis', () async {
      final page = await _repository().search(_filters());
      final names = [for (final e in page.items) e.member.fullName];

      expect(page.items.map((e) => e.member.ci).toSet(), hasLength(5));
      expect(names, contains('Ana Fernández'));
      expect(names, contains('Carlos Rodríguez'));
      expect(names, contains('Luis Martínez'));
    });

    test('las cinco cédulas pasan el validador del proyecto', () async {
      final page = await _repository().search(_filters());

      expect(page.items, hasLength(5));
      for (final entry in page.items) {
        expect(
          isValidUruguayanCi(entry.member.ci),
          isTrue,
          reason: entry.member.ci,
        );
      }
    });

    test('médico, especialidad y consultorio existen en los datos falsos '
        'del selector de médicos', () async {
      final admin = FakeAdminDatabase();
      final doctors = FakeShiftDatabase(admin, seed: false).activeDoctors();
      final page = await _repository().search(_filters());

      for (final entry in page.items) {
        final doctor = doctors.firstWhere((d) => d.id == entry.doctor.id);
        expect(doctor.firstName, entry.doctor.firstName);
        expect(doctor.lastName, entry.doctor.lastName);
        final specialty = doctor.specialties.firstWhere(
          (s) => s.id == entry.specialty.id,
        );
        expect(specialty.name, entry.specialty.name);
        expect(specialty.requiresReferral, entry.specialty.requiresReferral);
        final clinic = admin.clinics.firstWhere((c) => c.id == entry.clinic.id);
        expect(clinic.name, entry.clinic.name);
        expect(clinic.location, entry.clinic.location);
      }
    });
  });

  group('filtros', () {
    test('arrived=true da las 2 con llegada', () async {
      final page = await _repository().search(
        _filters().copyWith(arrived: () => true),
      );

      expect(_ids(page), [9001, 9002]);
      expect(page.total, 2);
    });

    test('arrived=false da las 3 sin llegada', () async {
      final page = await _repository().search(
        _filters().copyWith(arrived: () => false),
      );

      expect(_ids(page), [9003, 9004, 9005]);
      expect(page.total, 3);
    });

    test('por la CI de Ana da solo la de Ana', () async {
      final page = await _repository().search(
        _filters().copyWith(ci: () => '90000046'),
      );

      expect(_ids(page), [9001]);
      expect(page.items.single.member.fullName, 'Ana Fernández');
    });

    test('la CI se busca con puntos y guion también', () async {
      final page = await _repository().search(
        _filters().copyWith(ci: () => '9.000.004-6'),
      );

      expect(_ids(page), [9001]);
    });

    test('una CI que no está da vacío', () async {
      final page = await _repository().search(
        _filters().copyWith(ci: () => '12345672'),
      );

      expect(page.items, isEmpty);
      expect(page.total, 0);
    });

    test('por el identificador de una consulta da una', () async {
      final page = await _repository().search(
        _filters().copyWith(appointmentId: () => '9003'),
      );

      expect(_ids(page), [9003]);
    });

    test('un identificador que no existe da vacío', () async {
      final page = await _repository().search(
        _filters().copyWith(appointmentId: () => '15'),
      );

      expect(page.items, isEmpty);
    });

    test('por médico da las suyas', () async {
      final repository = _repository();

      final mendez = await repository.search(
        _filters().copyWith(doctorId: () => 4),
      );
      final silva = await repository.search(
        _filters().copyWith(doctorId: () => 6),
      );
      final acosta = await repository.search(
        _filters().copyWith(doctorId: () => 7),
      );

      expect(_ids(mendez), [9001, 9002]);
      expect(_ids(silva), [9003, 9004]);
      expect(_ids(acosta), [9005]);
    });

    test('por la fecha de mañana da vacío', () async {
      final page = await _repository().search(
        _filters().copyWith(date: DateTime.utc(2026, 10, 27)),
      );

      expect(page.items, isEmpty);
      expect(page.total, 0);
    });

    test('por la fecha de ayer da vacío', () async {
      final page = await _repository().search(
        _filters().copyWith(date: DateTime.utc(2026, 10, 25)),
      );

      expect(page.items, isEmpty);
    });

    test('por estado NO_ATENDIDA da 1', () async {
      final page = await _repository().search(
        _filters().copyWith(status: () => 'NO_ATENDIDA'),
      );

      expect(_ids(page), [9002]);
      expect(page.total, 1);
    });

    test('por estado AGENDADA da 2', () async {
      final page = await _repository().search(
        _filters().copyWith(status: () => 'AGENDADA'),
      );

      expect(_ids(page), [9001, 9004]);
    });

    test('los filtros se combinan', () async {
      final repository = _repository();

      final withArrival = await repository.search(
        _filters().copyWith(doctorId: () => 4, arrived: () => true),
      );
      final none = await repository.search(
        _filters().copyWith(doctorId: () => 6, arrived: () => true),
      );

      expect(_ids(withArrival), [9001, 9002]);
      expect(none.items, isEmpty);
      expect(none.total, 0);
    });
  });

  group('orden', () {
    test('por fecha y hora ascendente', () async {
      final page = await _repository().search(_filters());

      expect(_ids(page), [9001, 9002, 9003, 9004, 9005]);
    });

    test('por fecha y hora descendente', () async {
      final page = await _repository().search(
        _filters().copyWith(ascending: false),
      );

      expect(_ids(page), [9005, 9004, 9003, 9002, 9001]);
    });

    test('por hora de llegada ascendente: primero las llegadas, por hora, y '
        'al final las que no llegaron', () async {
      final page = await _repository().search(
        _filters().copyWith(order: ScheduleOrder.arrivalTime),
      );

      // 9002 llegó a las 08:40 y 9001 a las 08:55.
      expect(_ids(page), [9002, 9001, 9003, 9004, 9005]);
    });

    test('por hora de llegada descendente: las que no llegaron siguen al '
        'final', () async {
      final page = await _repository().search(
        _filters().copyWith(order: ScheduleOrder.arrivalTime, ascending: false),
      );

      expect(_ids(page), [9001, 9002, 9003, 9004, 9005]);
    });
  });

  group('páginas', () {
    test('size 2 page 1 devuelve las filas 3 y 4, con total 5', () async {
      final result = await _repository().search(
        ScheduleFilters(date: _today, page: 1, size: 2),
      );

      expect(_ids(result), [9003, 9004]);
      expect(result.total, 5);
      expect(result.page, 1);
      expect(result.size, 2);
      expect(result.hasPrevious, isTrue);
      expect(result.hasNext, isTrue);
    });

    test('la última página trae lo que queda', () async {
      final result = await _repository().search(
        ScheduleFilters(date: _today, page: 2, size: 2),
      );

      expect(_ids(result), [9005]);
      expect(result.total, 5);
      expect(result.hasNext, isFalse);
    });

    test(
      'una página más allá del final está vacía, con el mismo total',
      () async {
        final result = await _repository().search(
          ScheduleFilters(date: _today, page: 3, size: 2),
        );

        expect(result.items, isEmpty);
        expect(result.total, 5);
      },
    );

    test('el total es el del conjunto filtrado', () async {
      final result = await _repository().search(
        ScheduleFilters(date: _today, size: 1, page: 1, arrived: false),
      );

      expect(_ids(result), [9004]);
      expect(result.total, 3);
    });
  });
}
