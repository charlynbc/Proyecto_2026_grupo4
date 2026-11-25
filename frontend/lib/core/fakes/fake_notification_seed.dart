import '../../features/agenda/models/appointment.dart';
import '../../features/notificaciones/models/app_notification.dart';
import '../utils/ui_date.dart';
import '../utils/uruguay_time.dart';
import 'fake_admin_database.dart';
import 'fake_appointment_seed.dart';

/// La socia de los datos de prueba (`TestData.people`).
const String kFakeMemberCi = '12345672';

/// Otro socio, para probar que el servidor solo lista los avisos propios.
const String kFakeOtherMemberCi = '90000046';

/// El id de la atención (de la historia clínica falsa) de la consulta atendida
/// de la socia de prueba: los avisos de historia actualizada la llevan como
/// `atencionId`. Es la atención 14 de `FakeMedicalHistoryRepository`, de
/// Medicina General como esa consulta.
const int kFakeAttendedAtencionId = 14;

/// Un aviso guardado en el Fake: a quién le pertenece ([ownerCi]) y, si es un
/// recordatorio diferido, cuándo le toca aparecer ([scheduledFor]). Como el
/// servidor, solo se lista a su dueño y recién desde [scheduledFor].
class FakeStoredNotification {
  const FakeStoredNotification(
    this.notification, {
    this.ownerCi = kFakeMemberCi,
    this.scheduledFor,
  });

  final AppNotification notification;
  final String ownerCi;
  final DateTime? scheduledFor;
}

const Map<String, String> _titles = {
  'AGENDA': 'Consulta agendada',
  'CANCELACION': 'Consulta cancelada',
  'SUSPENSION': 'Turno suspendido',
  'HISTORIA_ACTUALIZADA': 'Historia clínica actualizada',
  'RECORDATORIO': 'Recordatorio de consulta',
};

const List<String> _typeCycle = [
  'AGENDA',
  'RECORDATORIO',
  'HISTORIA_ACTUALIZADA',
  'CANCELACION',
  'SUSPENSION',
];

/// Cuánto hace que se creó cada uno de los 26 avisos visibles de la socia de
/// prueba, del 1 al 26 (el 1 es el más viejo). Los ids 12 y 13, y los 25 y 26,
/// comparten instante a propósito para probar el desempate por id. El más
/// nuevo es de hace 5 horas y el más viejo de hace 100 días.
const List<Duration> _ago = [
  Duration(days: 100),
  Duration(days: 95),
  Duration(days: 92),
  Duration(days: 88),
  Duration(days: 80),
  Duration(days: 75),
  Duration(days: 70),
  Duration(days: 66),
  Duration(days: 60),
  Duration(days: 55),
  Duration(days: 50),
  Duration(days: 45),
  Duration(days: 45),
  Duration(days: 40),
  Duration(days: 36),
  Duration(days: 30),
  Duration(days: 26),
  Duration(days: 21),
  Duration(days: 17),
  Duration(days: 12),
  Duration(days: 9),
  Duration(days: 6),
  Duration(days: 3),
  Duration(days: 1),
  Duration(hours: 5),
  Duration(hours: 5),
];

/// La consulta de la semilla a la que se refiere un aviso de ese [type], o
/// `null` si no cuelga de ninguna.
///
/// `SUSPENSION` va sin consulta: sería una cancelada por la institución y el
/// Fake de consultas todavía no tiene ninguna. Cuando la tenga, se la puede
/// enlazar acá (el contrato permite `consultaId` nulo).
Appointment? _appointmentFor(String type, List<Appointment> appointments) {
  Appointment withStatus(String status) =>
      appointments.firstWhere((a) => a.status == status);
  return switch (type) {
    'AGENDA' || 'RECORDATORIO' => withStatus('AGENDADA'),
    'CANCELACION' => withStatus('CANCELADA_SOCIO'),
    'HISTORIA_ACTUALIZADA' => withStatus('ATENDIDA'),
    _ => null,
  };
}

/// El texto sale de los datos de la consulta: no afirma nada que ella no diga
/// (por eso el recordatorio no dice "mañana").
String _content(String type, Appointment? appointment) {
  if (appointment == null) {
    return type == 'SUSPENSION'
        ? 'Una de tus consultas fue cancelada por la institución. Motivo: el '
              'médico no atiende ese día.'
        : 'Se agendó una consulta a tu nombre.';
  }
  final specialty = appointment.specialty.name;
  final date = formatUiDate(appointment.date);
  final detail =
      'Horario: ${appointment.timeRange} (número ${appointment.number}).';
  return switch (type) {
    'AGENDA' =>
      'Tu consulta de $specialty quedó agendada para el $date. $detail',
    'RECORDATORIO' => 'Tenés consulta de $specialty el $date. $detail',
    'CANCELACION' =>
      'Tu consulta de $specialty del $date fue cancelada a tu solicitud. '
          '$detail',
    _ =>
      'Tu historia clínica fue actualizada tras tu consulta de $specialty '
          'del $date. $detail',
  };
}

AppNotification _n(
  int id,
  String type,
  List<Appointment> appointments,
  DateTime createdAt, {
  bool linked = true,
}) {
  final appointment = linked ? _appointmentFor(type, appointments) : null;
  return AppNotification(
    id: id,
    type: type,
    title: _titles[type]!,
    consultaId: appointment?.id,
    atencionId: type == 'HISTORIA_ACTUALIZADA' && appointment != null
        ? kFakeAttendedAtencionId
        : null,
    content: _content(type, appointment),
    createdAt: createdAt,
  );
}

/// Los avisos con que arranca el Fake, relativos a [now] para que la lista
/// siempre tenga fechas verosímiles.
///
/// La socia de prueba tiene 26 avisos visibles (varias páginas de 10 y de 20).
/// Los que se refieren a una consulta cuelgan de las tres de
/// `seedMemberAppointments` (ids 1, 2 y 3) y repiten sus datos reales; los de
/// suspensión van sin consulta. Además hay avisos que el servidor no le
/// mostraría, para ejercitar sus reglas: dos recordatorios que le tocan
/// aparecer en el futuro y tres avisos de otro socio (sin consulta, porque las
/// del Fake son de la socia de prueba).
///
/// Las consultas se arman con la misma semilla que usa el Fake de agenda, con
/// el día de Uruguay de [now]; [appointments] permite pasarlas ya armadas.
List<FakeStoredNotification> fakeNotificationSeed(
  DateTime now, {
  List<Appointment>? appointments,
}) {
  var nextId = 1;
  final consultas =
      appointments ??
      seedMemberAppointments(
        today: UruguayTime.today(now: now),
        admin: FakeAdminDatabase(),
        newId: () => nextId++,
      );
  return [
    for (var id = 1; id <= _ago.length; id++)
      FakeStoredNotification(
        _n(
          id,
          _typeCycle[(id - 1) % _typeCycle.length],
          consultas,
          now.subtract(_ago[id - 1]),
        ),
      ),
    FakeStoredNotification(
      _n(
        101,
        'RECORDATORIO',
        consultas,
        now.subtract(const Duration(hours: 2)),
      ),
      scheduledFor: now.add(const Duration(days: 1)),
    ),
    FakeStoredNotification(
      _n(
        102,
        'RECORDATORIO',
        consultas,
        now.subtract(const Duration(hours: 1)),
      ),
      scheduledFor: now.add(const Duration(days: 3)),
    ),
    for (var id = 201; id <= 203; id++)
      FakeStoredNotification(
        _n(
          id,
          'AGENDA',
          consultas,
          now.subtract(const Duration(hours: 3)),
          linked: false,
        ),
        ownerCi: kFakeOtherMemberCi,
      ),
  ];
}
