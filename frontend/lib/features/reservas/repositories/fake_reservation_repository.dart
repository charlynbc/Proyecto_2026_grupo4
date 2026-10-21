import '../../../core/fakes/fake_database.dart';
import '../models/reservation.dart';
import 'reservation_repository.dart';

/// Implementación en memoria de [ReservationRepository] para
/// `USE_FAKES=true`. Comparte estado con `FakeAgendaRepository` a través de
/// [FakeDatabase]. Cancelar una reserva que no existe o ya estaba cancelada
/// falla como un 404 ([ReservationNotFoundException]).
class FakeReservationRepository implements ReservationRepository {
  FakeReservationRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeDatabase _db;
  final Duration latency;

  @override
  Future<List<Reservation>> listMine() async {
    await Future<void>.delayed(latency);
    return List.unmodifiable(_db.reservations);
  }

  @override
  Future<void> cancel({required int reservationId}) async {
    await Future<void>.delayed(latency);
    if (!_db.cancelReservation(reservationId)) {
      throw const ReservationNotFoundException();
    }
  }
}
