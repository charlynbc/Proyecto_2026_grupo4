import '../models/reservation.dart';

abstract class ReservationRepository {
  Future<List<Reservation>> listMine();

  Future<void> cancel({required int reservationId});
}

class ReservationNotFoundException implements Exception {
  const ReservationNotFoundException([
    this.message = 'Esta reserva ya no existe o ya estaba cancelada.',
  ]);
  final String message;
  @override
  String toString() => message;
}

class ReservationException implements Exception {
  const ReservationException([
    this.message = 'No pudimos completar la operación. Intentá de nuevo.',
  ]);
  final String message;
  @override
  String toString() => message;
}
