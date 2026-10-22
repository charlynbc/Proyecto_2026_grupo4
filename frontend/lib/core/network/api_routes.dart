/// Todas las rutas de la API, en un solo lugar. Ningún repository ni servicio
/// escribe una ruta literal: cambiar una ruta es cambiar una línea acá y la
/// fila correspondiente de `docs/api/endpoints-usados.md`.
///
/// Los parámetros de consulta (`?fecha=`, `?ci=`, etc.) no forman parte de la
/// ruta: se pasan con `queryParameters`.
class ApiRoutes {
  ApiRoutes._();

  // --- Semana 1 (#1 a #17) ---------------------------------------------

  static const String authLogin = '/api/auth/login';
  static const String authRefresh = '/api/auth/refresh';
  static const String authLogout = '/api/auth/logout';
  static const String authFirstLoginRequest =
      '/api/auth/primer-ingreso/solicitar';
  static const String authFirstLoginComplete =
      '/api/auth/primer-ingreso/completar';
  static const String specialties = '/api/especialidades';
  static const String clinics = '/api/consultorios';
  static const String doctors = '/api/medicos';
  static const String users = '/api/usuarios';
  static const String weeklyShifts = '/api/turnos-semanales';
  static String weeklyShift(int id) => '/api/turnos-semanales/$id';
  static const String shifts = '/api/turnos';
  static const String availability = '/api/disponibilidad';
  static const String appointments = '/api/consultas';

  // --- Semana 2 y adelantos (#18 a #36) --------------------------------

  static String appointment(int id) => '/api/consultas/$id';
  static String appointmentCancel(int id) => '/api/consultas/$id/cancelar';
  static const String medicalHistory = '/api/historia-clinica';
  static String medicalHistoryEntry(int attentionId) =>
      '/api/historia-clinica/$attentionId';
  static const String shiftSuspensionsPreview =
      '/api/turnos/suspensiones/previsualizar';
  static const String shiftSuspensions = '/api/turnos/suspensiones';
  static const String shiftReinstatements = '/api/turnos/rehabilitaciones';
  static const String arrivalsTodayAppointments =
      '/api/avisos-llegada/consultas-hoy';
  static const String arrivals = '/api/avisos-llegada';
  static const String schedules = '/api/agendas';
  static const String doctorShifts = '/api/medico/turnos';
  static String doctorShiftNumbers(int shiftId) =>
      '/api/medico/turnos/$shiftId/numeros';
  static String doctorAppointmentResult(int appointmentId) =>
      '/api/medico/consultas/$appointmentId/resultado';
  static const String notifications = '/api/notificaciones';
  static const String devices = '/api/dispositivos';
  static const String statsSpecialties = '/api/estadisticas/especialidades';
  static const String statsShifts = '/api/estadisticas/turnos';
  static const String statsAppointments = '/api/estadisticas/consultas';

  static const String pocPushRegistration = '/api/notificaciones/registro';

  /// Todas las rutas, con un id de ejemplo (`1`) donde la ruta lo lleva.
  /// Sirve para los tests: si se agrega una ruta, se agrega acá también.
  static List<String> get all => [
    authLogin,
    authRefresh,
    authLogout,
    authFirstLoginRequest,
    authFirstLoginComplete,
    specialties,
    clinics,
    doctors,
    users,
    weeklyShifts,
    weeklyShift(1),
    shifts,
    availability,
    appointments,
    appointment(1),
    appointmentCancel(1),
    medicalHistory,
    medicalHistoryEntry(1),
    shiftSuspensionsPreview,
    shiftSuspensions,
    shiftReinstatements,
    arrivalsTodayAppointments,
    arrivals,
    schedules,
    doctorShifts,
    doctorShiftNumbers(1),
    doctorAppointmentResult(1),
    notifications,
    devices,
    statsSpecialties,
    statsShifts,
    statsAppointments,
    pocPushRegistration,
  ];
}
