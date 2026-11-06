import 'available_number.dart';

/// Una especialidad de un médico, como la manda `GET /api/medicos` (#10):
/// solo `id` y `nombre`. Para el socio la respuesta no trae `requierePase`,
/// por eso no se reutiliza `Specialty`, que lo exige.
class SpecialtyRef {
  const SpecialtyRef({required this.id, required this.name});

  factory SpecialtyRef.fromJson(Map<String, dynamic> json) =>
      SpecialtyRef(id: json['id'] as int, name: json['nombre'] as String);

  final int id;
  final String name;
}

/// Un médico activo con las especialidades que ejerce (`GET /api/medicos`).
/// Está en la lista aunque no tenga números libres.
class DoctorWithSpecialties extends DoctorRef {
  const DoctorWithSpecialties({
    required super.id,
    required super.firstName,
    required super.lastName,
    required this.specialties,
  });

  factory DoctorWithSpecialties.fromJson(Map<String, dynamic> json) =>
      DoctorWithSpecialties(
        id: json['id'] as int,
        firstName: json['nombre'] as String,
        lastName: json['apellido'] as String,
        specialties: [
          for (final specialty in json['especialidades'] as List<dynamic>)
            SpecialtyRef.fromJson(specialty as Map<String, dynamic>),
        ],
      );

  final List<SpecialtyRef> specialties;

  /// El médico ejerce la especialidad [specialtyId].
  bool attends(int specialtyId) =>
      specialties.any((specialty) => specialty.id == specialtyId);
}

/// Lo que devuelve `GET /api/medicos`: una lista JSON sin envoltorio. Se
/// acepta también `{ "items": [...] }`, como dice el contrato. Cualquier otra
/// forma es un [FormatException].
List<DoctorWithSpecialties> doctorsFromJson(Object? body) {
  final items = switch (body) {
    List<dynamic>() => body,
    {'items': final List<dynamic> items} => items,
    _ => throw const FormatException('Respuesta de médicos inesperada'),
  };
  return [
    for (final item in items)
      DoctorWithSpecialties.fromJson(item as Map<String, dynamic>),
  ];
}
