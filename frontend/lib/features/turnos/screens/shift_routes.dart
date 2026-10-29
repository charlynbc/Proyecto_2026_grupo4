/// Consulta de turnos del funcionario (RF-17): la sección "Turnos".
const String kShiftsPath = '/funcionario/turnos';

/// Listado de turnos del médico.
const String kDoctorShiftsPath = '/medico/turnos';

/// Detalle de un turno concreto del médico.
const String kDoctorShiftDetailPath = '/medico/turnos/:id';

/// La ruta concreta del detalle de un turno del médico [id].
String doctorShiftDetailLocation(int id) => '/medico/turnos/$id';

/// Alta de turno semanal (RF-13), colgada de la consulta.
const String kNewWeeklyShiftPath = '/funcionario/turnos/nuevo';

/// Detalle de una configuración semanal: el patrón de ruta, con `:id`.
const String kWeeklyShiftDetailPath = '/funcionario/turnos/configuracion/:id';

/// La ruta concreta del detalle de la configuración semanal [id].
String weeklyShiftDetailLocation(int id) =>
    '/funcionario/turnos/configuracion/$id';
