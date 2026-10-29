import '../../../core/fakes/fake_shift_database.dart';
import '../models/shift_state.dart';
import '../models/suspension_filter.dart';
import '../models/suspension_preview.dart';
import '../models/suspension_result.dart';
import 'shift_repository.dart';
import 'shift_suspension_repository.dart';

/// Máximo de caracteres de la observación (contrato #24).
const int _maxObservationLength = 1000;

/// Implementación en memoria de [ShiftSuspensionRepository] para
/// `USE_FAKES=true`. Aplica las reglas del contrato (#23 y #24) y valida todo
/// antes de cambiar nada, así que suspender es todo o nada.
///
/// La base falsa no lleva consultas, así que las cuenta este repositorio: las
/// de [appointmentsByShift] y, para los turnos que no están ahí, `id % 3`
/// (algunos turnos con consultas y otros sin).
class FakeShiftSuspensionRepository implements ShiftSuspensionRepository {
  FakeShiftSuspensionRepository(
    this._db, {
    this.appointmentsByShift = const {},
    required this.today,
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeShiftDatabase _db;

  /// Consultas agendadas por id de turno.
  final Map<int, int> appointmentsByShift;

  /// Hoy en Uruguay, como clave de día en UTC. Las fechas anteriores no se
  /// pueden suspender.
  final DateTime Function() today;
  final Duration latency;

  @override
  Future<SuspensionPreview> preview(List<int> ids) async {
    await Future<void>.delayed(latency);
    _validateIds(ids);
    return _previewOf(_suspendableShifts(ids));
  }

  @override
  Future<SuspensionResult> suspend({
    required SuspensionFilter filter,
    required List<int> ids,
    String? observation,
    required int confirmedCount,
  }) async {
    await Future<void>.delayed(latency);
    _validateIds(ids);
    if ((observation?.trim().length ?? 0) > _maxObservationLength) {
      throw const ShiftValidationException(
        'La observación puede tener hasta 1000 caracteres.',
      );
    }
    if (filter.fromDate.isAfter(filter.toDate)) {
      throw const ShiftValidationException(
        'La fecha "Desde" no puede ser posterior a la fecha "Hasta".',
      );
    }
    final shifts = _existingShifts(ids);
    for (final shift in shifts) {
      if (shift.doctorId != filter.doctorId ||
          shift.specialtyId != filter.specialtyId ||
          shift.date.isBefore(filter.fromDate) ||
          shift.date.isAfter(filter.toDate)) {
        throw const ShiftValidationException(
          'Hay turnos que no corresponden al médico, la especialidad o las '
          'fechas elegidas. Volvé a buscar y elegí de nuevo.',
        );
      }
    }
    _checkSuspendable(shifts);
    final preview = _previewOf(shifts);
    if (preview.totalAppointments != confirmedCount) {
      throw const StaleSuspensionConfirmationException(
        'La cantidad de consultas a cancelar cambió. Revisá los datos y '
        'confirmá de nuevo.',
      );
    }

    for (final shift in shifts) {
      _db.suspendShift(shift.id);
    }
    return SuspensionResult(
      shifts: [
        for (final shift in shifts)
          SuspendedShift(shiftId: shift.id, date: shift.date),
      ],
      cancelledAppointments: preview.totalAppointments,
    );
  }

  void _validateIds(List<int> ids) {
    if (ids.isEmpty) {
      throw const ShiftValidationException('Elegí al menos un turno.');
    }
    if (ids.any((id) => id <= 0) || ids.toSet().length != ids.length) {
      throw const ShiftValidationException(
        'Los turnos elegidos no son válidos. Volvé a elegirlos.',
      );
    }
  }

  /// Los turnos de [ids], en ese orden. Si falta alguno no devuelve ninguno.
  List<FakeShift> _existingShifts(List<int> ids) {
    final shifts = <FakeShift>[];
    for (final id in ids) {
      final matches = _db.shifts.where((s) => s.id == id);
      if (matches.isEmpty) throw const ShiftNotFoundException();
      shifts.add(matches.first);
    }
    return shifts;
  }

  List<FakeShift> _suspendableShifts(List<int> ids) {
    final shifts = _existingShifts(ids);
    _checkSuspendable(shifts);
    return shifts;
  }

  void _checkSuspendable(List<FakeShift> shifts) {
    final now = today();
    for (final shift in shifts) {
      if (shift.state != ShiftState.active || shift.date.isBefore(now)) {
        throw const ShiftNotSuspendableException(
          'Alguna de las fechas ya está suspendida o ya pasó. No se '
          'suspendió ninguna.',
        );
      }
    }
  }

  SuspensionPreview _previewOf(List<FakeShift> shifts) {
    final dates = [
      for (final shift in shifts)
        AffectedShiftDate(
          shiftId: shift.id,
          date: shift.date,
          startMinutes: shift.startMinutes,
          endMinutes: shift.endMinutes,
          appointmentsToCancel: appointmentsByShift[shift.id] ?? shift.id % 3,
        ),
    ];
    return SuspensionPreview(
      affectedDates: dates,
      totalAppointments: dates.fold(
        0,
        (sum, d) => sum + d.appointmentsToCancel,
      ),
    );
  }
}
