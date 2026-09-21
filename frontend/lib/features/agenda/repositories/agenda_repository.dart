import '../models/professional.dart';
import '../models/time_slot.dart';

abstract class AgendaRepository {
  Future<List<Professional>> listProfessionals();

  /// Los horarios libres de [professionalId] en [day] (hora de Uruguay,
  /// ver `UruguayTime`). El backend ya filtra a horarios futuros y libres.
  Future<List<TimeSlot>> listTimeSlots({
    required int professionalId,
    required DateTime day,
  });

  Future<void> reserve({required int timeSlotId});
}

class TimeSlotTakenException implements Exception {
  const TimeSlotTakenException([
    this.message = 'Otro socio tomó este horario recién. Elegí otro.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class TimeSlotStartedException implements Exception {
  const TimeSlotStartedException([
    this.message = 'Ese horario ya comenzó y no se puede reservar.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AgendaException implements Exception {
  const AgendaException([
    this.message = 'No pudimos completar la operación. Intentá de nuevo.',
  ]);

  final String message;

  @override
  String toString() => message;
}
