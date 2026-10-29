import 'package:agenda_medica/features/agendas/models/schedule_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una consulta de la agenda tal como la manda el servidor (contrato #28).
Map<String, dynamic> entryJson({
  String start = '09:20',
  String end = '09:40',
  String status = 'AGENDADA',
  Object? arrivedAt = '2026-10-20T08:55:12-03:00',
}) => {
  'consultaId': 9001,
  'socio': {'ci': '45678911', 'nombre': 'Lucía', 'apellido': 'Fernández'},
  'medico': {'id': 17, 'nombre': 'Marta', 'apellido': 'Rodríguez'},
  'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
  'fecha': '2026-10-20',
  'horaInicio': start,
  'horaFin': end,
  'consultorio': {'id': 5, 'nombre': 'Consultorio 5', 'ubicacion': 'Piso 2'},
  'estado': status,
  'llegadaEn': arrivedAt,
};

void main() {
  group('ScheduleEntry.fromJson', () {
    test('lee todos los campos del ejemplo del contrato', () {
      final entry = ScheduleEntry.fromJson(entryJson());

      expect(entry.appointmentId, 9001);
      expect(entry.member.ci, '45678911');
      expect(entry.member.firstName, 'Lucía');
      expect(entry.member.lastName, 'Fernández');
      expect(entry.doctor.id, 17);
      expect(entry.doctor.fullName, 'Marta Rodríguez');
      expect(entry.specialty.id, 3);
      expect(entry.specialty.name, 'Cardiología');
      expect(entry.specialty.requiresReferral, isTrue);
      expect(entry.date, DateTime.utc(2026, 10, 20));
      expect(entry.startMinutes, 560); // 09:20 = 9 * 60 + 20
      expect(entry.endMinutes, 580); // 09:40 = 9 * 60 + 40
      expect(entry.clinic.id, 5);
      expect(entry.clinic.name, 'Consultorio 5');
      expect(entry.clinic.location, 'Piso 2');
      expect(entry.status, 'AGENDADA');
    });

    test('la hora de inicio "08:30" se muestra "08:30"', () {
      final entry = ScheduleEntry.fromJson(entryJson(start: '08:30'));

      expect(entry.startTime, '08:30');
      expect(entry.startMinutes, 510); // 8 * 60 + 30
    });

    test('la hora de fin "09:40" se muestra "09:40"', () {
      expect(ScheduleEntry.fromJson(entryJson()).endTime, '09:40');
    });

    test('llegadaEn null: no hay hora de llegada', () {
      final entry = ScheduleEntry.fromJson(entryJson(arrivedAt: null));

      expect(entry.arrivedAt, isNull);
      expect(entry.arrivalTime, isNull);
    });

    test('llegadaEn con -03:00 muestra la hora de Uruguay "08:35"', () {
      final entry = ScheduleEntry.fromJson(
        entryJson(arrivedAt: '2026-10-22T08:35:00-03:00'),
      );

      expect(entry.arrivalTime, '08:35');
      // 08:35 en Uruguay son las 11:35 UTC.
      expect(entry.arrivedAt, DateTime.utc(2026, 10, 22, 11, 35));
    });

    test('llegadaEn en UTC se muestra en hora de Uruguay', () {
      final entry = ScheduleEntry.fromJson(
        entryJson(arrivedAt: '2026-10-22T11:35:00Z'),
      );

      expect(entry.arrivalTime, '08:35');
    });

    test('llegadaEn sin zona horaria es un error de formato', () {
      expect(
        () =>
            ScheduleEntry.fromJson(entryJson(arrivedAt: '2026-10-22T08:35:00')),
        throwsFormatException,
      );
    });

    test('NO_ASISTIO es un estado válido', () {
      expect(
        ScheduleEntry.fromJson(entryJson(status: 'NO_ASISTIO')).status,
        'NO_ASISTIO',
      );
    });

    test('NO_ATENDIDA es un estado válido', () {
      expect(
        ScheduleEntry.fromJson(entryJson(status: 'NO_ATENDIDA')).status,
        'NO_ATENDIDA',
      );
    });

    test('los siete estados del contrato son válidos', () {
      const statuses = [
        'AGENDADA',
        'ATENDIDA',
        'CANCELADA_SOCIO',
        'CANCELADA_INSTITUCION',
        'NO_SE_PRESENTO',
        'NO_ASISTIO',
        'NO_ATENDIDA',
      ];
      for (final status in statuses) {
        expect(
          ScheduleEntry.fromJson(entryJson(status: status)).status,
          status,
        );
      }
    });

    test('un estado fuera de la lista es un error de formato', () {
      for (final status in ['PENDIENTE', 'agendada', '']) {
        expect(
          () => ScheduleEntry.fromJson(entryJson(status: status)),
          throwsFormatException,
          reason: 'estado "$status"',
        );
      }
    });

    test('una hora con formato inesperado es un error de formato', () {
      expect(
        () => ScheduleEntry.fromJson(entryJson(start: '9h20')),
        throwsFormatException,
      );
    });

    test('un campo obligatorio faltante es un error de lectura', () {
      const required = [
        'consultaId',
        'socio',
        'medico',
        'especialidad',
        'fecha',
        'horaInicio',
        'horaFin',
        'consultorio',
        'estado',
      ];
      for (final key in required) {
        final json = entryJson()..remove(key);
        expect(
          () => ScheduleEntry.fromJson(json),
          throwsA(anyOf(isA<FormatException>(), isA<TypeError>())),
          reason: 'sin $key',
        );
      }
    });

    test('un dato del socio faltante es un error de lectura', () {
      for (final key in ['ci', 'nombre', 'apellido']) {
        final json = entryJson();
        (json['socio'] as Map<String, dynamic>).remove(key);
        expect(
          () => ScheduleEntry.fromJson(json),
          throwsA(anyOf(isA<FormatException>(), isA<TypeError>())),
          reason: 'socio sin $key',
        );
      }
    });
  });
}
