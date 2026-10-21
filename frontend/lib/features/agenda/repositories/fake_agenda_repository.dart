import '../../../core/fakes/datos_prueba.dart';
import '../../../core/fakes/fake_database.dart';
import '../models/professional.dart';
import '../models/time_slot.dart';
import 'agenda_repository.dart';

/// Implementación en memoria de [AgendaRepository] para `USE_FAKES=true`.
///
/// Los médicos de prueba hacen de profesionales y cada número de sus turnos
/// es un horario. Reserva errores como los del contrato: 409 si el horario ya
/// lo tomó otro ([TimeSlotTakenException]) y 400 si ya comenzó
/// ([TimeSlotStartedException]).
class FakeAgendaRepository implements AgendaRepository {
  FakeAgendaRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FakeDatabase _db;
  final Duration latency;
  final DateTime Function() _clock;

  @override
  Future<List<Professional>> listProfessionals() async {
    await Future<void>.delayed(latency);
    return [
      for (final doctor in TestData.doctors)
        Professional(id: doctor.id, name: doctor.name),
    ];
  }

  @override
  Future<List<TimeSlot>> listTimeSlots({
    required int professionalId,
    required DateTime day,
  }) async {
    await Future<void>.delayed(latency);
    // `day` es la fecha de Uruguay; su inicio es 03:00 UTC.
    final from = DateTime.utc(day.year, day.month, day.day, 3);
    final until = from.add(const Duration(days: 1));
    final now = _clock().toUtc();
    return [
      for (final number in _db.numbers)
        if (number.doctorId == professionalId &&
            !number.start.isBefore(from) &&
            number.start.isBefore(until) &&
            number.start.isAfter(now) &&
            !_db.isTaken(number.id))
          TimeSlot(
            id: number.id,
            professionalId: number.doctorId,
            start: number.start,
            end: number.end,
          ),
    ];
  }

  @override
  Future<void> reserve({required int timeSlotId}) async {
    await Future<void>.delayed(latency);
    final number = _db.numberById(timeSlotId);
    if (number == null) throw const AgendaException();
    if (_db.isTaken(number.id)) throw const TimeSlotTakenException();
    if (_db.isContested(number)) {
      _db.markTaken(number.id);
      throw const TimeSlotTakenException();
    }
    if (_db.isStarted(number) || !number.start.isAfter(_clock().toUtc())) {
      _db.markTaken(number.id);
      throw const TimeSlotStartedException();
    }
    _db.addReservation(number);
  }
}
