import 'available_number.dart';

/// Un médico con el que el socio tuvo consultas, junto con la especialidad de
/// una de ellas. Un mismo médico puede aparecer con más de una especialidad.
class AppointmentDoctor {
  const AppointmentDoctor({required this.doctor, required this.specialtyId});

  final DoctorRef doctor;
  final int specialtyId;

  @override
  bool operator ==(Object other) =>
      other is AppointmentDoctor &&
      other.doctor.id == doctor.id &&
      other.specialtyId == specialtyId;

  @override
  int get hashCode => Object.hash(doctor.id, specialtyId);
}
