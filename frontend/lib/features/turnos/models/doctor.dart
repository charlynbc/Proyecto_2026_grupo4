import '../../especialidades/models/specialty.dart';

/// Referencia a un médico (`MedicoRef` del contrato).
class DoctorRef {
  const DoctorRef({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  factory DoctorRef.fromJson(Map<String, dynamic> json) => DoctorRef(
    id: json['id'] as int,
    firstName: json['nombre'] as String,
    lastName: json['apellido'] as String,
  );

  final int id;
  final String firstName;
  final String lastName;

  /// Como se muestra: "nombre apellido" (el contrato no trae el tratamiento).
  String get fullName => '$firstName $lastName';
}

/// Un médico activo con las especialidades que ejerce, para elegirlo al dar
/// de alta un turno.
class Doctor extends DoctorRef {
  const Doctor({
    required super.id,
    required super.firstName,
    required super.lastName,
    required this.specialties,
  });

  final List<Specialty> specialties;
}
