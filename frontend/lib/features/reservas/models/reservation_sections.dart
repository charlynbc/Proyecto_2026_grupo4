import 'reservation.dart';

/// Separa "próximas" (ACTIVA con horario futuro) de "historial" (canceladas
/// y ACTIVA con horario ya pasado). El backend nunca cambia el estado de una
/// reserva cuando su horario pasa: "activa" significa "no cancelada", no
/// "futura", así que esta separación se calcula acá, no viene del backend.
({List<Reservation> upcoming, List<Reservation> history}) splitReservations(
  List<Reservation> reservations,
  DateTime now,
) {
  final upcoming =
      [
        for (final r in reservations)
          if (r.status == ReservationStatus.active && r.start.isAfter(now)) r,
      ]..sort((a, b) => a.start.compareTo(b.start));

  final history =
      [
        for (final r in reservations)
          if (!(r.status == ReservationStatus.active && r.start.isAfter(now)))
            r,
      ]..sort((a, b) => b.start.compareTo(a.start));

  return (upcoming: upcoming, history: history);
}
