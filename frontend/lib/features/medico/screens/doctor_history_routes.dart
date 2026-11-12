const String kDoctorPatientHistoryPath = '/medico/pacientes/:socioId/historia';

String doctorPatientHistoryLocation(int socioId, {String? patientName}) {
  final path = '/medico/pacientes/$socioId/historia';
  if (patientName == null || patientName.isEmpty) return path;
  return '$path?paciente=${Uri.encodeComponent(patientName)}';
}
