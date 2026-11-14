import '../../features/notificaciones/models/app_notification.dart';

/// Los avisos con que arranca la socia de los datos de prueba, para que la
/// lista de Avisos tenga qué mostrar (y varias páginas) con `USE_FAKES=true`.
/// Cuelgan de las tres consultas de `seedMemberAppointments` (ids 1, 2 y 3).
/// Los instantes están en UTC; los ids 12 y 13, y los 25 y 26, comparten
/// instante a propósito para probar el desempate por id.
final List<AppNotification> kFakeNotificationSeed = [
  _n(
    1,
    'AGENDA',
    3,
    'Tu consulta de Medicina General con Carla Méndez quedó agendada para el 23/09/2026 a las 14:00.',
    DateTime.utc(2026, 9, 10, 15),
  ),
  _n(
    2,
    'RECORDATORIO',
    3,
    'Mañana tenés consulta de Medicina General a las 14:00.',
    DateTime.utc(2026, 9, 22, 12),
  ),
  _n(
    3,
    'HISTORIA_ACTUALIZADA',
    3,
    'Tu historia clínica fue actualizada.',
    DateTime.utc(2026, 9, 23, 18, 30),
  ),
  _n(
    4,
    'AGENDA',
    2,
    'Tu consulta de Medicina General con Carla Méndez quedó agendada para el 13/10/2026 a las 08:00.',
    DateTime.utc(2026, 9, 28, 13, 10),
  ),
  _n(
    5,
    'CANCELACION',
    2,
    'Tu consulta del 13/10/2026 fue cancelada a tu solicitud.',
    DateTime.utc(2026, 10, 2, 14, 45),
  ),
  _n(
    6,
    'AGENDA',
    1,
    'Tu consulta de Dermatología con Florencia Acosta quedó agendada para el 05/11/2026 a las 09:30.',
    DateTime.utc(2026, 10, 21, 15),
  ),
  _n(
    7,
    'RECORDATORIO',
    2,
    'Mañana tenés consulta de Medicina General a las 08:00.',
    DateTime.utc(2026, 10, 12, 11),
  ),
  _n(
    8,
    'SUSPENSION',
    3,
    'Tu consulta del 23/09/2026 fue cancelada por la institución. Horario: 14:00 a 14:30 (número 3). El médico no atiende ese día.',
    DateTime.utc(2026, 10, 3, 13),
  ),
  _n(
    9,
    'HISTORIA_ACTUALIZADA',
    1,
    'Tu historia clínica fue actualizada.',
    DateTime.utc(2026, 10, 24, 17, 15),
  ),
  _n(
    10,
    'CANCELACION',
    3,
    'Tu consulta del 23/09/2026 fue cancelada por la institución. Motivo: el médico no puede atender.',
    DateTime.utc(2026, 10, 25, 11, 20),
  ),
  _n(
    11,
    'AGENDA',
    2,
    'Tu consulta de Medicina General con Carla Méndez quedó agendada para el 20/11/2026 a las 10:00.',
    DateTime.utc(2026, 10, 26, 14),
  ),
  _n(
    12,
    'RECORDATORIO',
    1,
    'Mañana tenés consulta de Dermatología a las 09:30.',
    DateTime.utc(2026, 11, 4, 12),
  ),
  _n(
    13,
    'SUSPENSION',
    1,
    'Tu consulta del 05/11/2026 fue cancelada por la institución. Horario: 09:30 a 10:00 (número 2). Se reprograma la semana próxima.',
    DateTime.utc(2026, 11, 4, 12),
  ),
  _n(
    14,
    'AGENDA',
    3,
    'Tu consulta de Cardiología con Esteban Silva quedó agendada para el 02/12/2026 a las 11:00.',
    DateTime.utc(2026, 11, 5, 16),
  ),
  _n(
    15,
    'CANCELACION',
    1,
    'Tu consulta del 05/11/2026 fue cancelada a tu solicitud.',
    DateTime.utc(2026, 11, 5, 18, 5),
  ),
  _n(
    16,
    'HISTORIA_ACTUALIZADA',
    2,
    'Tu historia clínica fue actualizada.',
    DateTime.utc(2026, 11, 6, 13, 40),
  ),
  _n(
    17,
    'AGENDA',
    1,
    'Tu consulta de Pediatría con Florencia Acosta quedó agendada para el 10/12/2026 a las 15:30.',
    DateTime.utc(2026, 11, 7, 12, 30),
  ),
  _n(
    18,
    'RECORDATORIO',
    3,
    'Mañana tenés consulta de Cardiología a las 11:00.',
    DateTime.utc(2026, 11, 8, 12),
  ),
  _n(
    19,
    'SUSPENSION',
    2,
    'Tu consulta del 20/11/2026 fue cancelada por la institución. Horario: 10:00 a 10:30 (número 4).',
    DateTime.utc(2026, 11, 9, 14, 15),
  ),
  _n(
    20,
    'CANCELACION',
    2,
    'Tu consulta del 20/11/2026 fue cancelada por la institución. Motivo: licencia del médico.',
    DateTime.utc(2026, 11, 10, 15),
  ),
  _n(
    21,
    'HISTORIA_ACTUALIZADA',
    3,
    'Tu historia clínica fue actualizada.',
    DateTime.utc(2026, 11, 11, 19),
  ),
  _n(
    22,
    'AGENDA',
    2,
    'Tu consulta de Traumatología con Carla Méndez quedó agendada para el 15/12/2026 a las 09:00.',
    DateTime.utc(2026, 11, 12, 13),
  ),
  _n(
    23,
    'RECORDATORIO',
    2,
    'Mañana tenés consulta de Traumatología a las 09:00.',
    DateTime.utc(2026, 11, 13, 12),
  ),
  _n(
    24,
    'CANCELACION',
    3,
    'Tu consulta del 02/12/2026 fue cancelada a tu solicitud.',
    DateTime.utc(2026, 11, 13, 20, 50),
  ),
  _n(
    25,
    'SUSPENSION',
    1,
    'Tu consulta del 10/12/2026 fue cancelada por la institución. Horario: 15:30 a 16:00 (número 5).',
    DateTime.utc(2026, 11, 14, 11),
  ),
  _n(
    26,
    'HISTORIA_ACTUALIZADA',
    1,
    'Tu historia clínica fue actualizada.',
    DateTime.utc(2026, 11, 14, 11),
  ),
];

const Map<String, String> _titles = {
  'AGENDA': 'Consulta agendada',
  'CANCELACION': 'Consulta cancelada',
  'SUSPENSION': 'Turno suspendido',
  'HISTORIA_ACTUALIZADA': 'Historia clínica actualizada',
  'RECORDATORIO': 'Recordatorio de consulta',
};

AppNotification _n(
  int id,
  String type,
  int consultaId,
  String content,
  DateTime createdAt,
) => AppNotification(
  id: id,
  type: type,
  title: _titles[type]!,
  consultaId: consultaId,
  content: content,
  createdAt: createdAt,
);
