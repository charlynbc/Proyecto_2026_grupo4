import 'package:agenda_medica/features/turnos/models/shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un `TurnoDTO` del contrato (#15).
Map<String, dynamic> shiftJson({String estado = 'ACTIVO'}) => {
  'id': 301,
  'turnoSemanalId': 120,
  'fecha': '2026-10-20',
  'diaSemana': 2,
  'horaInicio': '09:00',
  'horaFin': '10:30',
  'medico': {'id': 17, 'nombre': 'Marta', 'apellido': 'Rodríguez'},
  'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
  'consultorio': {
    'id': 5,
    'nombre': 'Consultorio 5',
    'ubicacion': 'Piso 2, ala norte',
  },
  'cantidadNumeros': 3,
  'estado': estado,
};

void main() {
  group('Shift.fromJson', () {
    test('lee un TurnoDTO del contrato', () {
      final shift = Shift.fromJson(shiftJson());
      expect(shift.id, 301);
      expect(shift.weeklyShiftId, 120);
      expect(shift.date, DateTime.utc(2026, 10, 20));
      expect(shift.weekday, 2);
      expect(shift.startMinutes, 9 * 60);
      expect(shift.endMinutes, 10 * 60 + 30);
      expect(shift.doctor.id, 17);
      expect(shift.doctor.firstName, 'Marta');
      expect(shift.doctor.lastName, 'Rodríguez');
      expect(shift.specialty.id, 3);
      expect(shift.specialty.name, 'Cardiología');
      expect(shift.specialty.requiresReferral, isTrue);
      expect(shift.clinic.id, 5);
      expect(shift.clinic.name, 'Consultorio 5');
      expect(shift.clinic.location, 'Piso 2, ala norte');
      expect(shift.numberCount, 3);
      expect(shift.state, ShiftState.active);
    });

    test('lee un turno suspendido', () {
      expect(
        Shift.fromJson(shiftJson(estado: 'SUSPENDIDO')).state,
        ShiftState.suspended,
      );
    });

    test('un estado desconocido tira FormatException', () {
      expect(
        () => Shift.fromJson(shiftJson(estado: 'ARCHIVADO')),
        throwsFormatException,
      );
    });
  });

  group('ShiftState.fromApi', () {
    test('reconoce los dos estados del contrato', () {
      expect(ShiftState.fromApi('ACTIVO'), ShiftState.active);
      expect(ShiftState.fromApi('SUSPENDIDO'), ShiftState.suspended);
    });

    test('un valor desconocido o en minúscula tira FormatException', () {
      expect(() => ShiftState.fromApi('activo'), throwsFormatException);
      expect(() => ShiftState.fromApi(''), throwsFormatException);
    });
  });

  group('ShiftPage', () {
    test('lee items, page, size y total', () {
      final page = ShiftPage.fromJson({
        'items': [shiftJson()],
        'page': 1,
        'size': 20,
        'total': 41,
      });
      expect(page.items.single.id, 301);
      expect(page.page, 1);
      expect(page.size, 20);
      expect(page.total, 41);
      expect(page.pageCount, 3);
      expect(page.hasPrevious, isTrue);
      expect(page.hasNext, isTrue);
    });

    test('con 20 resultados justos hay una sola página', () {
      const page = ShiftPage(items: [], page: 0, size: 20, total: 20);
      expect(page.pageCount, 1);
      expect(page.hasNext, isFalse);
      expect(page.hasPrevious, isFalse);
    });

    test('sin resultados hay una página (vacía)', () {
      const page = ShiftPage(items: [], page: 0, size: 20, total: 0);
      expect(page.pageCount, 1);
    });

    test('la última página no tiene siguiente', () {
      const page = ShiftPage(items: [], page: 2, size: 20, total: 41);
      expect(page.hasNext, isFalse);
    });
  });

  group('ShiftFilters.toQueryParameters', () {
    test('sin filtros manda solo orden, sentido, página y tamaño', () {
      expect(const ShiftFilters().toQueryParameters(), {
        'orden': 'fecha',
        'sentido': 'asc',
        'page': 0,
        'size': 20,
      });
    });

    test('manda cada filtro con el nombre y el formato del contrato', () {
      final params = ShiftFilters(
        doctorId: 17,
        specialtyId: 3,
        weekday: 2,
        fromDate: DateTime.utc(2026, 10, 5),
        toDate: DateTime.utc(2026, 12, 15),
        state: ShiftState.suspended,
        order: ShiftOrder.doctor,
        ascending: false,
        page: 2,
        size: 50,
      ).toQueryParameters();
      expect(params, {
        'medicoId': 17,
        'especialidadId': 3,
        'diaSemana': 2,
        'fechaDesde': '2026-10-05',
        'fechaHasta': '2026-12-15',
        'estado': 'SUSPENDIDO',
        'orden': 'medico',
        'sentido': 'desc',
        'page': 2,
        'size': 50,
      });
    });

    test('los valores de orden son fecha, medico y especialidad', () {
      expect(ShiftOrder.values.map((o) => o.apiValue), [
        'fecha',
        'medico',
        'especialidad',
      ]);
    });
  });

  group('ShiftFilters.copyWith', () {
    test('cambia un campo y conserva el resto', () {
      final filters = ShiftFilters(doctorId: 17, weekday: 2);
      final next = filters.copyWith(page: 3);
      expect(next.page, 3);
      expect(next.doctorId, 17);
      expect(next.weekday, 2);
    });

    test('permite borrar un filtro (volver a null)', () {
      final filters = ShiftFilters(doctorId: 17, state: ShiftState.active);
      final next = filters.copyWith(doctorId: () => null);
      expect(next.doctorId, isNull);
      expect(next.state, ShiftState.active);
    });

    test('es igual si tiene los mismos valores', () {
      expect(
        ShiftFilters(doctorId: 1, fromDate: DateTime.utc(2026, 10, 5)),
        ShiftFilters(doctorId: 1, fromDate: DateTime.utc(2026, 10, 5)),
      );
      expect(
        ShiftFilters(doctorId: 1).hashCode,
        ShiftFilters(doctorId: 1).hashCode,
      );
      expect(ShiftFilters(doctorId: 1), isNot(ShiftFilters(doctorId: 2)));
    });
  });
}
