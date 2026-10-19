/// Un consultorio (`ConsultorioRef`, contrato 1.8). `nombre` y `ubicacion`
/// son los del contrato #9; la pregunta P-38 sigue abierta.
class Clinic {
  const Clinic({required this.id, required this.name, required this.location});

  final int id;
  final String name;

  /// Piso o sector (`ubicacion`).
  final String location;

  factory Clinic.fromJson(Map<String, dynamic> json) => Clinic(
    id: json['id'] as int,
    name: json['nombre'] as String,
    location: json['ubicacion'] as String,
  );
}
