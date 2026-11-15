import '../../features/notificaciones/models/app_notification.dart';
import '../utils/ui_date.dart';
import '../utils/uruguay_time.dart';

/// La socia de los datos de prueba (`TestData.people`).
const String kFakeMemberCi = '12345672';

/// Otro socio, para probar que el servidor solo lista los avisos propios.
const String kFakeOtherMemberCi = '90000046';

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

String _content(String type, DateTime createdAt) {
  final date = formatUiDate(
    UruguayTime.toUruguay(createdAt.add(const Duration(days: 14))),
  );
  return switch (type) {
    'AGENDA' =>
      'Tu consulta de Medicina General con Carla Méndez quedó agendada para '
          'el $date a las 14:00.',
    'RECORDATORIO' => 'Mañana tenés consulta de Medicina General a las 14:00.',
    'HISTORIA_ACTUALIZADA' => 'Tu historia clínica fue actualizada.',
    'CANCELACION' => 'Tu consulta del $date fue cancelada a tu solicitud.',
    _ =>
      'Tu consulta del $date fue cancelada por la institución. Horario: '
          '14:00 a 14:30 (número 3). Motivo: el médico no atiende ese día.',
  };
}

AppNotification _n(int id, String type, int consultaId, DateTime createdAt) =>
    AppNotification(
      id: id,
      type: type,
      title: _titles[type]!,
      consultaId: consultaId,
      content: _content(type, createdAt),
      createdAt: createdAt,
    );

/// Los avisos con que arranca el Fake, relativos a [now] para que la lista
/// siempre tenga fechas verosímiles.
///
/// La socia de prueba tiene 26 avisos visibles (varias páginas de 10 y de 20),
/// colgados de las tres consultas de `seedMemberAppointments` (ids 1, 2 y 3).
/// Además hay avisos que el servidor no le mostraría, para ejercitar sus
/// reglas: dos recordatorios que le tocan aparecer en el futuro y tres avisos
/// de otro socio.
List<FakeStoredNotification> fakeNotificationSeed(DateTime now) => [
  for (var id = 1; id <= _ago.length; id++)
    FakeStoredNotification(
      _n(
        id,
        _typeCycle[(id - 1) % _typeCycle.length],
        (id % 3) + 1,
        now.subtract(_ago[id - 1]),
      ),
    ),
  FakeStoredNotification(
    _n(101, 'RECORDATORIO', 1, now.subtract(const Duration(hours: 2))),
    scheduledFor: now.add(const Duration(days: 1)),
  ),
  FakeStoredNotification(
    _n(102, 'RECORDATORIO', 2, now.subtract(const Duration(hours: 1))),
    scheduledFor: now.add(const Duration(days: 3)),
  ),
  for (var id = 201; id <= 203; id++)
    FakeStoredNotification(
      _n(id, 'AGENDA', 1, now.subtract(const Duration(hours: 3))),
      ownerCi: kFakeOtherMemberCi,
    ),
];
