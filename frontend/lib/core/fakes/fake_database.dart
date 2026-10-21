import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/reservas/models/reservation.dart';
import '../utils/uruguay_time.dart';
import 'datos_prueba.dart';

/// Estado en memoria compartido por los repositories falsos: lo que se
/// reserva en la agenda aparece en "mis reservas", y lo que se cancela vuelve
/// a quedar libre. Se pierde al recargar la app.
class FakeDatabase {
  FakeDatabase({required DateTime today, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      shifts = TestData.shiftsFrom(today) {
    _seedReservations();
  }

  final DateTime Function() _clock;
  final List<TestShift> shifts;
  final List<Reservation> reservations = [];
  final Set<int> _takenNumberIds = {};
  int _nextReservationId = 1;

  Iterable<TestNumber> get numbers => shifts.expand((s) => s.numbers);

  TestNumber? numberById(int id) {
    for (final number in numbers) {
      if (number.id == id) return number;
    }
    return null;
  }

  bool isTaken(int numberId) => _takenNumberIds.contains(numberId);

  void markTaken(int numberId) => _takenNumberIds.add(numberId);

  /// Un número "disputado": figura libre, pero otro socio lo toma justo antes
  /// de que se confirme la reserva (error 409 al reservar).
  bool isContested(TestNumber number) =>
      number.index == 1 && number.shiftId % 5 == 0;

  /// Un número "iniciado": figura libre, pero para cuando se confirma la
  /// reserva el turno ya empezó (error 400 al reservar).
  bool isStarted(TestNumber number) =>
      number.index == 2 && number.shiftId % 7 == 0;

  Reservation addReservation(TestNumber number) {
    final doctor = TestData.doctors.firstWhere((d) => d.id == number.doctorId);
    final reservation = Reservation(
      id: _nextReservationId++,
      status: ReservationStatus.active,
      createdAt: _clock().toUtc(),
      timeSlotId: number.id,
      start: number.start,
      end: number.end,
      professionalId: doctor.id,
      professionalName: doctor.name,
    );
    markTaken(number.id);
    reservations.add(reservation);
    return reservation;
  }

  /// Cancela la reserva y libera su número. Devuelve `false` si no existe o
  /// ya estaba cancelada.
  bool cancelReservation(int reservationId) {
    final index = reservations.indexWhere((r) => r.id == reservationId);
    if (index == -1) return false;
    final current = reservations[index];
    if (current.status == ReservationStatus.cancelled) return false;
    reservations[index] = Reservation(
      id: current.id,
      status: ReservationStatus.cancelled,
      createdAt: current.createdAt,
      cancelledAt: _clock().toUtc(),
      timeSlotId: current.timeSlotId,
      start: current.start,
      end: current.end,
      professionalId: current.professionalId,
      professionalName: current.professionalName,
    );
    _takenNumberIds.remove(current.timeSlotId);
    return true;
  }

  /// Una reserva activa y una cancelada, para que "mis reservas" no arranque
  /// vacía.
  void _seedReservations() {
    final all = numbers.toList();
    if (all.length < 10) return;
    addReservation(all[4]);
    addReservation(all[9]);
    cancelReservation(2);
  }
}

/// Un único estado en memoria por ejecución de la app.
final fakeDatabaseProvider = Provider<FakeDatabase>(
  (ref) => FakeDatabase(today: UruguayTime.today()),
);
