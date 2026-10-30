/// Los siete estados de una consulta (`EstadoConsulta`, contrato 1.7) con el
/// texto con que se muestran, en el orden en que se ofrecen al filtrar.
///
/// El texto de `Appointment.statusLabel` (consultas del socio) dice algunas
/// cosas distintas, así que la agenda del funcionario tiene el suyo.
const Map<String, String> kScheduleStatusLabels = {
  'AGENDADA': 'Agendada',
  'ATENDIDA': 'Atendida',
  'CANCELADA_SOCIO': 'Cancelada por el socio',
  'CANCELADA_INSTITUCION': 'Cancelada por la institución',
  'NO_SE_PRESENTO': 'No se presentó',
  'NO_ASISTIO': 'No asistió',
  'NO_ATENDIDA': 'No atendida',
};

/// El texto de [status]; uno que no se conoce se muestra tal cual.
String scheduleStatusLabel(String status) =>
    kScheduleStatusLabels[status] ?? status;
