import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({String status = 'AGENDADA'}) => {
  'id': 9001,
  'estado': status,
  'fecha': '2026-10-20',
  'numero': 2,
  'horaInicio': '09:20',
  'horaFin': '09:40',
  'medico': {'id': 17, 'nombre': 'Marta', 'apellido': 'Rodríguez'},
  'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
  'consultorio': {'id': 5, 'nombre': 'Consultorio 5', 'ubicacion': 'Piso 2'},
  'paseId': null,
  'agendadaEn': '2026-10-14T10:12:45-03:00',
  'canceladaEn': null,
  'motivoCancelacion': null,
};

// Los siete estados de EstadoConsulta (contrato 1.7) con el texto que ve el
// socio. Los nombres salen de RF-11 y los demas requerimientos.
const _labels = {
  'AGENDADA': 'Agendada',
  'ATENDIDA': 'Atendida',
  'CANCELADA_SOCIO': 'Cancelada por el socio',
  'CANCELADA_INSTITUCION': 'Cancelada por la institución',
  'NO_SE_PRESENTO': 'No se presentó a la consulta',
  'NO_ASISTIO': 'No asistió',
  'NO_ATENDIDA': 'No atendida',
};

void main() {
  group('Appointment.fromJson: estado', () {
    test('lee los siete estados del contrato', () {
      expect(_labels, hasLength(7));
      for (final status in _labels.keys) {
        expect(
          Appointment.fromJson(_json(status: status)).status,
          status,
          reason: status,
        );
      }
    });

    for (final status in ['REPROGRAMADA', 'agendada', 'Agendada', '']) {
      test('el estado "$status" tira FormatException', () {
        expect(
          () => Appointment.fromJson(_json(status: status)),
          throwsFormatException,
        );
      });
    }

    test('sin estado la respuesta es malformada', () {
      final json = _json()..remove('estado');

      expect(() => Appointment.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('Appointment.statusLabel', () {
    for (final entry in _labels.entries) {
      test('${entry.key} se muestra como "${entry.value}"', () {
        final label = Appointment.fromJson(_json(status: entry.key))
            .statusLabel;

        expect(label, entry.value);
        expect(label, isNot(entry.key));
        expect(label, isNot(contains('_')));
      });
    }
  });

  group('Appointment.fromJson: cancelable', () {
    test('si el servidor no lo manda (backend viejo) queda en null', () {
      final appointment = Appointment.fromJson(_json());

      expect(_json().containsKey('cancelable'), isFalse);
      expect(appointment.cancelable, isNull);
    });

    test('true se conserva', () {
      final json = _json()..['cancelable'] = true;

      expect(Appointment.fromJson(json).cancelable, isTrue);
    });

    test('false se conserva', () {
      final json = _json()..['cancelable'] = false;

      expect(Appointment.fromJson(json).cancelable, isFalse);
    });

    test('un null explicito tambien es null', () {
      final json = _json()..['cancelable'] = null;

      expect(Appointment.fromJson(json).cancelable, isNull);
    });

    for (final value in <Object>['si', 'true', 1, 0]) {
      test('el valor $value no es booleano y la respuesta es malformada', () {
        final json = _json()..['cancelable'] = value;

        expect(() => Appointment.fromJson(json), throwsA(isA<TypeError>()));
      });
    }

    test('los constructores existentes no piden el campo', () {
      final appointment = Appointment.fromJson(_json());
      final rebuilt = Appointment(
        id: appointment.id,
        status: appointment.status,
        date: appointment.date,
        number: appointment.number,
        startMinutes: appointment.startMinutes,
        endMinutes: appointment.endMinutes,
        doctor: appointment.doctor,
        specialty: appointment.specialty,
        clinic: appointment.clinic,
        referralId: appointment.referralId,
        bookedAt: appointment.bookedAt,
        cancelledAt: appointment.cancelledAt,
        cancellationReason: appointment.cancellationReason,
      );

      expect(rebuilt.cancelable, isNull);
    });
  });
}
