/// Una especialidad del catálogo (`EspecialidadRef`, contrato 1.8).
class Specialty {
  const Specialty({
    required this.id,
    required this.name,
    required this.requiresReferral,
  });

  final int id;
  final String name;

  /// Agendar en esta especialidad exige un pase (`requierePase`).
  final bool requiresReferral;

  factory Specialty.fromJson(Map<String, dynamic> json) => Specialty(
    id: json['id'] as int,
    name: json['nombre'] as String,
    requiresReferral: json['requierePase'] as bool,
  );
}
