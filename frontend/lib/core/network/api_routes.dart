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
  static const String availableReferrals = '/api/socios/me/pases/disponibles';

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
  static String doctorAppointmentCancel(int appointmentId) =>
      '/api/medico/consultas/$appointmentId/cancelar';
  static String doctorShiftCancel(int shiftId) =>
      '/api/medico/turnos/$shiftId/cancelar';
  static String doctorPatientMedicalHistory(int memberId) =>
      '/api/medico/pacientes/$memberId/historia-clinica';
  static const String doctorAttentions = '/api/medico/atenciones';
  static String doctorAttention(int attentionId) =>
      '/api/medico/atenciones/$attentionId';
  static const String doctorReferrals = '/api/medico/pases';
  static String staffAppointmentCancel(int appointmentId) =>
      '/api/funcionario/consultas/$appointmentId/cancelar';
  static const String notifications = '/api/notificaciones';
  static const String devices = '/api/dispositivos';
  static const String statsSpecialties = '/api/estadisticas/especialidades';
  static const String statsShifts = '/api/estadisticas/turnos';
  static const String statsAppointments = '/api/estadisticas/consultas';
  static const String statsAbsences = '/api/estadisticas/inasistencias';
  static const String statsReferrals = '/api/estadisticas/pases';
  static const String statsTimeSlots = '/api/estadisticas/franjas';

  // --- RF-04, RF-05, RF-06 y RF-20: cuenta y recuperación (endpoints 45 a 51) ---
  // La edición de datos personales (PATCH) y el pedido de cambio de correo
  // usan `accountMe`; la modificación del consultorio de un turno semanal
  // (PATCH) usa `weeklyShift`.

  static const String authChangePassword = '/api/auth/cambiar-contrasena';
  static const String accountMe = '/api/cuentas/me';
  static const String authPasswordRecoveryRequest =
      '/api/auth/recuperacion/solicitar';
  static const String authPasswordRecoveryComplete =
      '/api/auth/recuperacion/completar';
  static const String authEmailChangeConfirm =
      '/api/auth/cambio-correo/confirmar';

  // --- RF-02 y RF-05: validar el enlace antes de pedir los datos (filas 63 y 64) ---
  // Las dos son POST públicas con el token en el cuerpo. No consumen el enlace.

  static const String authFirstLoginValidate =
      '/api/auth/primer-ingreso/validar';
  static const String authPasswordRecoveryValidate =
      '/api/auth/recuperacion/validar';

  // --- RF-30 y RF-32: cargas masivas (filas 52 a 55) ---
  // Las cuatro son POST y solo para ADMINISTRADOR: vista previa y confirmación
  // de la carga de especialidades y de la carga de usuarios.

  static const String specialtiesImportPreview =
      '/api/especialidades/importaciones/previsualizar';
  static const String specialtiesImportConfirm =
      '/api/especialidades/importaciones/confirmar';
  static const String usersImportPreview =
      '/api/usuarios/importaciones/previsualizar';
  static const String usersImportConfirm =
      '/api/usuarios/importaciones/confirmar';

  // --- RF-34, RF-38 y RF-45: administración (filas 56 a 62) ---
  // Todas son solo para ADMINISTRADOR. Las dos primeras son POST (carga masiva
  // de consultorios). Las tres con id de especialidad, consultorio o cuenta
  // son PATCH (`specialty`, `clinic`, `user`: corrección de datos); las dos
  // últimas son POST sin cuerpo (inactivar y reactivar una cuenta de
  // empleado).

  static const String clinicsImportPreview =
      '/api/consultorios/importaciones/previsualizar';
  static const String clinicsImportConfirm =
      '/api/consultorios/importaciones/confirmar';
  static String specialty(int id) => '/api/especialidades/$id';
  static String clinic(int id) => '/api/consultorios/$id';
  static String user(int id) => '/api/usuarios/$id';
  static String userDeactivate(int id) => '/api/usuarios/$id/inactivar';
  static String userReactivate(int id) => '/api/usuarios/$id/reactivar';

  // --- RF-07 y RF-28: cartelera de novedades (filas 65 a 67) ---
  // `announcements` sirve para publicar (POST, solo ADMINISTRADOR) y para el
  // listado paginado (GET); `announcement` es el detalle (GET).

  static const String announcements = '/api/anuncios';
  static String announcement(int id) => '/api/anuncios/$id';

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
    availableReferrals,
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
    doctorAppointmentCancel(1),
    doctorShiftCancel(1),
    doctorPatientMedicalHistory(1),
    doctorAttentions,
    doctorAttention(1),
    doctorReferrals,
    staffAppointmentCancel(1),
    notifications,
    devices,
    statsSpecialties,
    statsShifts,
    statsAppointments,
    statsAbsences,
    statsReferrals,
    statsTimeSlots,
    authChangePassword,
    accountMe,
    authPasswordRecoveryRequest,
    authPasswordRecoveryComplete,
    authEmailChangeConfirm,
    authFirstLoginValidate,
    authPasswordRecoveryValidate,
    specialtiesImportPreview,
    specialtiesImportConfirm,
    usersImportPreview,
    usersImportConfirm,
    clinicsImportPreview,
    clinicsImportConfirm,
    specialty(1),
    clinic(1),
    user(1),
    userDeactivate(1),
    userReactivate(1),
    announcements,
    announcement(1),
    pocPushRegistration,
  ];
}
