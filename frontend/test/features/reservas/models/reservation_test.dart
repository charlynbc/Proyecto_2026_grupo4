import 'package:agenda_medica/features/reservas/models/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reservation.fromJson', () {
    test('mapea una reserva activa sin fecha de cancelación', () {
      final reservation = Reservation.fromJson({
        'id': 1,
        'estado': 'ACTIVA',
        'fechaCreacion': '2026-09-20T12:00:00-03:00',
        'fechaCancelacion': null,
        'horarioId': 10,
        'inicio': '2026-09-25T09:30:00-03:00',
        'fin': '2026-09-25T10:00:00-03:00',
        'profesionalId': 3,
        'profesional': 'Dra. Ana Pérez',
      });

      expect(reservation.id, 1);
      expect(reservation.status, ReservationStatus.active);
      expect(reservation.cancelledAt, isNull);
      expect(reservation.professionalName, 'Dra. Ana Pérez');
    });

    test('mapea una reserva cancelada con fecha de cancelación', () {
      final reservation = Reservation.fromJson({
        'id': 2,
        'estado': 'CANCELADA',
        'fechaCreacion': '2026-09-18T08:00:00-03:00',
        'fechaCancelacion': '2026-09-19T08:00:00-03:00',
        'horarioId': 11,
        'inicio': '2026-09-20T09:30:00-03:00',
        'fin': '2026-09-20T10:00:00-03:00',
        'profesionalId': 3,
        'profesional': 'Dra. Ana Pérez',
      });

      expect(reservation.status, ReservationStatus.cancelled);
      expect(reservation.cancelledAt, isNotNull);
    });

    test('tira FormatException ante un estado desconocido', () {
      expect(
        () => Reservation.fromJson({
          'id': 3,
          'estado': 'PENDIENTE',
          'fechaCreacion': '2026-09-20T12:00:00-03:00',
          'fechaCancelacion': null,
          'horarioId': 12,
          'inicio': '2026-09-25T09:30:00-03:00',
          'fin': '2026-09-25T10:00:00-03:00',
          'profesionalId': 3,
          'profesional': 'Dra. Ana Pérez',
        }),
        throwsFormatException,
      );
    });
  });
}
