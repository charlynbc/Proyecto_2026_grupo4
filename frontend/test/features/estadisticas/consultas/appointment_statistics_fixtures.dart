import 'package:agenda_medica/features/estadisticas/consultas/models/appointment_statistics.dart';

/// Las siete claves del servidor en el orden en que se muestran, escritas a
/// mano (no se toman de la implementación).
const statusKeys = [
  'AGENDADA',
  'ATENDIDA',
  'CANCELADA_SOCIO',
  'CANCELADA_INSTITUCION',
  'NO_ASISTIO',
  'NO_ATENDIDA',
  'NO_SE_PRESENTO',
];

/// Las siete etiquetas en el mismo orden, escritas a mano.
const statusLabels = [
  'Agendada',
  'Atendida',
  'Cancelada por el socio',
  'Cancelada por la institución',
  'No asistió',
  'No atendida',
  'No se presentó a la consulta',
];

/// La respuesta de ejemplo del contrato de `GET /api/estadisticas/consultas`.
Map<String, dynamic> contractBody() => {
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'estados': <String, dynamic>{
    'AGENDADA': 40,
    'ATENDIDA': 110,
    'CANCELADA_SOCIO': 20,
    'CANCELADA_INSTITUCION': 8,
    'NO_ASISTIO': 14,
    'NO_ATENDIDA': 5,
    'NO_SE_PRESENTO': 3,
  },
  'totalConsultas': 200,
  'canceladasPorSocio': 20,
  'porcentajeCancelacion': 10.0,
  'porcentajeCancelacionTexto': '10 %',
};

/// El mapa `estados` de [body], para tocarlo en un test.
Map<String, dynamic> statesOf(Map<String, dynamic> body) =>
    body['estados'] as Map<String, dynamic>;

/// Un `AppointmentStatistics` armado a mano para las pruebas de pantalla, con
/// [counts] en el orden de [statusKeys].
AppointmentStatistics statisticsOf({
  List<int> counts = const [40, 110, 20, 8, 14, 5, 3],
  int total = 200,
  int cancelled = 20,
  double? percentage = 10.0,
  String percentageText = '10 %',
}) => AppointmentStatistics(
  from: DateTime.utc(2026, 10, 1),
  to: DateTime.utc(2026, 10, 31),
  counts: {
    for (var i = 0; i < statusKeys.length; i++) statusKeys[i]: counts[i],
  },
  total: total,
  cancelledBySocio: cancelled,
  percentage: percentage,
  percentageText: percentageText,
);
