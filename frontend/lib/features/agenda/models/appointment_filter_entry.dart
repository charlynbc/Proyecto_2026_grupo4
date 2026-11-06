import 'available_number.dart';

/// Lo que hace falta de una consulta del socio para calcular las opciones de
/// los filtros de Mis consultas: su estado, su médico y su especialidad (con
/// el nombre que trae la propia consulta). Dos consultas con el mismo estado,
/// médico y especialidad dan la misma entrada.
class AppointmentFilterEntry {
  const AppointmentFilterEntry({
    required this.status,
    required this.doctor,
    required this.specialtyId,
    required this.specialtyName,
  });

  final String status;
  final DoctorRef doctor;
  final int specialtyId;
  final String specialtyName;

  @override
  bool operator ==(Object other) =>
      other is AppointmentFilterEntry &&
      other.status == status &&
      other.doctor.id == doctor.id &&
      other.specialtyId == specialtyId;

  @override
  int get hashCode => Object.hash(status, doctor.id, specialtyId);
}
