/// Resultado de una consulta del médico (RF-23): el patrón de ruta, con `:id`.
const String kDoctorResultPath = '/medico/consultas/:id/resultado';

/// La ruta concreta del resultado de la consulta [appointmentId]. Con
/// [patientName], lo manda en `?paciente=` para el encabezado, con los
/// espacios y los acentos codificados.
String doctorResultLocation(int appointmentId, {String? patientName}) {
  final path = '/medico/consultas/$appointmentId/resultado';
  if (patientName == null || patientName.isEmpty) return path;
  return '$path?paciente=${Uri.encodeComponent(patientName)}';
}
