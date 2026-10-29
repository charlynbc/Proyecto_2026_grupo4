import '../../../core/utils/uruguay_time.dart';

/// Aviso de llegada de un socio (RF-16): quién llegó, a qué hora y qué
/// funcionario lo registró.
class Arrival {
  const Arrival({
    required this.id,
    required this.memberCi,
    required this.memberFirstName,
    required this.memberLastName,
    required this.registeredAt,
    required this.registeredByFirstName,
    required this.registeredByLastName,
  });

  factory Arrival.fromJson(Map<String, dynamic> json) {
    final member = json['socio'] as Map<String, dynamic>;
    final registeredBy = json['registradaPor'] as Map<String, dynamic>;
    return Arrival(
      id: json['id'] as int,
      memberCi: member['ci'] as String,
      memberFirstName: member['nombre'] as String,
      memberLastName: member['apellido'] as String,
      registeredAt: DateTime.parse(json['registradaEn'] as String),
      registeredByFirstName: registeredBy['nombre'] as String,
      registeredByLastName: registeredBy['apellido'] as String,
    );
  }

  final int id;
  final String memberCi;
  final String memberFirstName;
  final String memberLastName;
  final DateTime registeredAt;
  final String registeredByFirstName;
  final String registeredByLastName;

  String get registeredByName => '$registeredByFirstName $registeredByLastName';

  /// Hora de llegada en hora de Uruguay, como "08:47".
  String get registeredTime {
    final local = UruguayTime.toUruguay(registeredAt);
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Resultado de registrar una llegada: [created] es `false` cuando el aviso
/// ya existía y el servidor devolvió el original (200 en vez de 201).
class ArrivalResult {
  const ArrivalResult({required this.arrival, required this.created});

  final Arrival arrival;
  final bool created;
}
