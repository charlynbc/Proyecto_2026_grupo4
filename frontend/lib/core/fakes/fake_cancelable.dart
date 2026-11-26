import '../../features/agenda/models/appointment.dart';
import '../utils/uruguay_time.dart';
import 'fake_database.dart';

/// Por qué una consulta no se puede cancelar, en el orden en que el servidor
/// lo evalúa: primero el estado, después la llegada y por último el plazo.
enum FakeCancelDenial { notScheduled, alreadyArrived, outsideWindow }

/// El plazo mínimo de anticipación para cancelar (2 horas por defecto en el
/// servidor).
const Duration kFakeCancelDeadline = Duration(hours: 2);

/// La regla de cancelación del servidor para los Fakes: `null` si se puede
/// cancelar, o el primer motivo que lo impide. La consulta tiene que estar
/// `AGENDADA`, el socio no puede haber registrado llegada ese día (la regla
/// mira el día, no la consulta) y el inicio no puede caer antes de [now] más
/// [kFakeCancelDeadline] (justo en el límite sí se puede).
///
/// Es la única copia de la regla: la usan el historial falso, para devolver
/// `cancelable`, y la cancelación falsa, para decidir si responde un error.
FakeCancelDenial? fakeCancelDenial(
  FakeDatabase db,
  Appointment appointment,
  DateTime now,
) {
  if (appointment.status != 'AGENDADA') return FakeCancelDenial.notScheduled;
  if (db.arrivedDays.contains(appointment.date)) {
    return FakeCancelDenial.alreadyArrived;
  }
  final start = UruguayTime.fromUruguay(
    appointment.date,
    appointment.startMinutes ~/ 60,
    appointment.startMinutes % 60,
  );
  if (start.difference(now.toUtc()) < kFakeCancelDeadline) {
    return FakeCancelDenial.outsideWindow;
  }
  return null;
}

/// El campo `cancelable` que mandaría el servidor para [appointment].
bool fakeCancelable(FakeDatabase db, Appointment appointment, DateTime now) =>
    fakeCancelDenial(db, appointment, now) == null;

/// La misma consulta con `cancelable` resuelto. `Appointment` no tiene
/// `copyWith`: se rearma campo por campo.
Appointment fakeWithCancelable(Appointment appointment, bool cancelable) =>
    Appointment(
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
      cancelable: cancelable,
    );
