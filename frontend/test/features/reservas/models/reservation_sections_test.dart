import 'package:agenda_medica/features/reservas/models/reservation.dart';
import 'package:agenda_medica/features/reservas/models/reservation_sections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22, 12, 0);

  Reservation makeReservation({
    required int id,
    required ReservationStatus status,
    required DateTime start,
  }) {
    return Reservation(
      id: id,
      status: status,
      createdAt: start,
      cancelledAt: null,
      timeSlotId: id,
      start: start,
      end: start.add(const Duration(minutes: 30)),
      professionalId: 1,
      professionalName: 'Dra. Ana Pérez',
    );
  }

  group('splitReservations', () {
    test(
      'una activa futura va a próximas; una activa pasada y una cancelada '
      'futura van a historial',
      () {
        final activeFuture = makeReservation(
          id: 1,
          status: ReservationStatus.active,
          start: now.add(const Duration(days: 1)),
        );
        final activePast = makeReservation(
          id: 2,
          status: ReservationStatus.active,
          start: now.subtract(const Duration(days: 1)),
        );
        final cancelledFuture = makeReservation(
          id: 3,
          status: ReservationStatus.cancelled,
          start: now.add(const Duration(days: 2)),
        );

        final sections = splitReservations([
          activeFuture,
          activePast,
          cancelledFuture,
        ], now);

        expect(sections.upcoming, [activeFuture]);
        expect(sections.history, containsAll([activePast, cancelledFuture]));
        expect(sections.history.length, 2);
      },
    );

    test('las próximas quedan ordenadas de la más cercana a la más lejana', () {
      final far = makeReservation(
        id: 1,
        status: ReservationStatus.active,
        start: now.add(const Duration(days: 5)),
      );
      final near = makeReservation(
        id: 2,
        status: ReservationStatus.active,
        start: now.add(const Duration(days: 1)),
      );

      final sections = splitReservations([far, near], now);

      expect(sections.upcoming, [near, far]);
    });

    test('una activa que empieza exactamente en now va a historial', () {
      final startsNow = makeReservation(
        id: 1,
        status: ReservationStatus.active,
        start: now,
      );

      final sections = splitReservations([startsNow], now);

      expect(sections.upcoming, isEmpty);
      expect(sections.history, [startsNow]);
    });
  });
}
