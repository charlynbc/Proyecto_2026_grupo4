import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hoy en los ejemplos de la tarjeta.
final DateTime _today = DateTime.utc(2026, 10, 26);

ScheduleFilters _filters() => ScheduleFilters(date: _today);

void main() {
  group('valores por defecto', () {
    test('fecha de hoy, por fecha y hora, ascendente, página 0 de a 20', () {
      final filters = _filters();

      expect(filters.date, _today);
      expect(filters.ci, isNull);
      expect(filters.appointmentId, isNull);
      expect(filters.doctorId, isNull);
      expect(filters.status, isNull);
      expect(filters.arrived, isNull);
      expect(filters.order, ScheduleOrder.dateTime);
      expect(filters.ascending, isTrue);
      expect(filters.page, 0);
      expect(filters.size, 20);
    });

    test('los valores del orden en el pedido', () {
      expect(ScheduleOrder.dateTime.apiValue, 'fechaHora');
      expect(ScheduleOrder.arrivalTime.apiValue, 'horaLlegada');
    });
  });

  group('toQueryParameters', () {
    test('sin filtros lleva fecha, orden, sentido, page y size', () {
      expect(_filters().toQueryParameters(), {
        'fecha': '2026-10-26',
        'orden': 'fechaHora',
        'sentido': 'asc',
        'page': 0,
        'size': 20,
      });
    });

    test('los filtros vacíos no se mandan', () {
      final filters = ScheduleFilters(date: _today, ci: '', appointmentId: '');

      expect(filters.toQueryParameters().keys.toSet(), {
        'fecha',
        'orden',
        'sentido',
        'page',
        'size',
      });
    });

    test('una cédula o un identificador sin dígitos no se mandan', () {
      final filters = ScheduleFilters(
        date: _today,
        ci: ' .- ',
        appointmentId: 'abc',
      );
      final query = filters.toQueryParameters();

      expect(query.containsKey('ci'), isFalse);
      expect(query.containsKey('consultaId'), isFalse);
    });

    test('llegada true agrega llegada=true', () {
      final query = ScheduleFilters(
        date: _today,
        arrived: true,
      ).toQueryParameters();

      expect(query['llegada'], true);
    });

    test('llegada false agrega llegada=false', () {
      final query = ScheduleFilters(
        date: _today,
        arrived: false,
      ).toQueryParameters();

      expect(query.containsKey('llegada'), isTrue);
      expect(query['llegada'], false);
    });

    test('llegada null no se manda', () {
      expect(_filters().toQueryParameters().containsKey('llegada'), isFalse);
    });

    test('la cédula se manda solo con dígitos', () {
      final query = ScheduleFilters(
        date: _today,
        ci: '9.000.004-6',
      ).toQueryParameters();

      expect(query['ci'], '90000046');
    });

    test('escribir 15 en el identificador manda consultaId=15', () {
      final query = ScheduleFilters(
        date: _today,
        appointmentId: '15',
      ).toQueryParameters();

      expect(query['consultaId'], 15);
    });

    test('el identificador con espacios alrededor manda solo el número', () {
      final query = ScheduleFilters(
        date: _today,
        appointmentId: ' 15 ',
      ).toQueryParameters();

      expect(query['consultaId'], 15);
    });

    test('elegir médico manda medicoId con su id', () {
      final query = ScheduleFilters(
        date: _today,
        doctorId: 17,
      ).toQueryParameters();

      expect(query['medicoId'], 17);
    });

    test('el estado se manda con su nombre exacto', () {
      for (final status in ['AGENDADA', 'NO_ASISTIO', 'CANCELADA_SOCIO']) {
        final query = ScheduleFilters(
          date: _today,
          status: status,
        ).toQueryParameters();

        expect(query['estado'], status);
      }
    });

    test('orden por hora de llegada, descendente y página 3', () {
      final query = ScheduleFilters(
        date: _today,
        order: ScheduleOrder.arrivalTime,
        ascending: false,
        page: 3,
      ).toQueryParameters();

      expect(query['orden'], 'horaLlegada');
      expect(query['sentido'], 'desc');
      expect(query['page'], 3);
    });

    test('con todos los filtros lleva todos los parámetros', () {
      final query = ScheduleFilters(
        date: DateTime.utc(2026, 1, 5),
        ci: '45678911',
        appointmentId: '9001',
        doctorId: 17,
        status: 'AGENDADA',
        arrived: true,
        order: ScheduleOrder.arrivalTime,
        ascending: false,
        page: 2,
      ).toQueryParameters();

      expect(query, {
        'ci': '45678911',
        'consultaId': 9001,
        'medicoId': 17,
        'fecha': '2026-01-05',
        'estado': 'AGENDADA',
        'llegada': true,
        'orden': 'horaLlegada',
        'sentido': 'desc',
        'page': 2,
        'size': 20,
      });
    });
  });

  group('cambiar un filtro vuelve a la primera página', () {
    ScheduleFilters onPageThree() => ScheduleFilters(
      date: _today,
      ci: '45678911',
      appointmentId: '9001',
      doctorId: 17,
      status: 'AGENDADA',
      arrived: true,
      page: 3,
    );

    test('la cédula', () {
      final result = onPageThree().withFilterChange(ci: () => '12345672');

      expect(result.ci, '12345672');
      expect(result.page, 0);
    });

    test('el identificador', () {
      final result = onPageThree().withFilterChange(appointmentId: () => '15');

      expect(result.appointmentId, '15');
      expect(result.page, 0);
    });

    test('el médico', () {
      final result = onPageThree().withFilterChange(doctorId: () => 18);

      expect(result.doctorId, 18);
      expect(result.page, 0);
    });

    test('la fecha', () {
      final result = onPageThree().withFilterChange(
        date: DateTime.utc(2026, 10, 27),
      );

      expect(result.date, DateTime.utc(2026, 10, 27));
      expect(result.page, 0);
    });

    test('el estado', () {
      final result = onPageThree().withFilterChange(status: () => 'ATENDIDA');

      expect(result.status, 'ATENDIDA');
      expect(result.page, 0);
    });

    test('la llegada', () {
      final result = onPageThree().withFilterChange(arrived: () => false);

      expect(result.arrived, false);
      expect(result.page, 0);
    });

    test('el orden', () {
      final result = onPageThree().withFilterChange(
        order: ScheduleOrder.arrivalTime,
      );

      expect(result.order, ScheduleOrder.arrivalTime);
      expect(result.page, 0);
    });

    test('el sentido', () {
      final result = onPageThree().withFilterChange(ascending: false);

      expect(result.ascending, isFalse);
      expect(result.page, 0);
    });

    test('un filtro se puede borrar con un getter que da null', () {
      final result = onPageThree().withFilterChange(
        ci: () => null,
        arrived: () => null,
      );

      expect(result.ci, isNull);
      expect(result.arrived, isNull);
      expect(result.page, 0);
    });

    test('lo que no se cambia se conserva', () {
      final result = onPageThree().withFilterChange(doctorId: () => 18);

      expect(result.ci, '45678911');
      expect(result.appointmentId, '9001');
      expect(result.status, 'AGENDADA');
      expect(result.arrived, true);
      expect(result.date, _today);
      expect(result.size, 20);
    });

    test('cambiar solo la página no vuelve a la primera', () {
      final result = onPageThree().copyWith(page: 4);

      expect(result.page, 4);
      expect(result.ci, '45678911');
      expect(result.doctorId, 17);
      expect(result.arrived, true);
    });
  });

  group('igualdad', () {
    ScheduleFilters full() => ScheduleFilters(
      date: _today,
      ci: '45678911',
      appointmentId: '9001',
      doctorId: 17,
      status: 'AGENDADA',
      arrived: true,
      order: ScheduleOrder.arrivalTime,
      ascending: false,
      page: 2,
    );

    test('dos filtros con los mismos valores son iguales', () {
      expect(full(), full());
      expect(full().hashCode, full().hashCode);
    });

    test('cualquier diferencia los hace distintos', () {
      final base = full();
      final others = [
        base.copyWith(date: DateTime.utc(2026, 10, 27)),
        base.copyWith(ci: () => '12345672'),
        base.copyWith(appointmentId: () => '9002'),
        base.copyWith(doctorId: () => 18),
        base.copyWith(status: () => 'ATENDIDA'),
        base.copyWith(arrived: () => false),
        base.copyWith(order: ScheduleOrder.dateTime),
        base.copyWith(ascending: true),
        base.copyWith(page: 3),
      ];
      for (final other in others) {
        expect(other, isNot(base));
      }
    });
  });
}
