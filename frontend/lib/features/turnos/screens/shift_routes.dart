/// Consulta de turnos del funcionario (RF-17): la sección "Turnos".
const String kShiftsPath = '/funcionario/turnos';

/// Alta de turno semanal (RF-13), colgada de la consulta.
const String kNewWeeklyShiftPath = '/funcionario/turnos/nuevo';

/// Suspensión de fechas de turnos (RF-14), colgada de la consulta.
const String kSuspendShiftsPath = '/funcionario/turnos/suspender';

/// Rehabilitar fechas suspendidas (RF-15), colgada de la consulta.
const String kReinstateShiftsPath = '/funcionario/turnos/rehabilitar';

/// Detalle de una configuración semanal: el patrón de ruta, con `:id`.
const String kWeeklyShiftDetailPath = '/funcionario/turnos/configuracion/:id';

/// La ruta concreta del detalle de la configuración semanal [id].
String weeklyShiftDetailLocation(int id) =>
    '/funcionario/turnos/configuracion/$id';
