import '../../../core/utils/uruguay_time.dart';
import '../../agenda/models/appointment.dart';

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

/// La llegada de hoy de un socio tal como la informa la búsqueda (fila 26 del
/// contrato): cuándo se registró y quién la registró, sin los datos del socio.
class TodayArrival {
  const TodayArrival({
    required this.registeredAt,
    required this.registeredByFirstName,
    required this.registeredByLastName,
  });

  factory TodayArrival.fromJson(Map<String, dynamic> json) {
    final registeredBy = json['registradaPor'] as Map<String, dynamic>;
    return TodayArrival(
      registeredAt: DateTime.parse(json['registradaEn'] as String),
      registeredByFirstName: registeredBy['nombre'] as String,
      registeredByLastName: registeredBy['apellido'] as String,
    );
  }

  factory TodayArrival.fromArrival(Arrival arrival) => TodayArrival(
    registeredAt: arrival.registeredAt,
    registeredByFirstName: arrival.registeredByFirstName,
    registeredByLastName: arrival.registeredByLastName,
  );

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

/// Lo que devuelve la búsqueda por cédula: las consultas agendadas de hoy y la
/// llegada de hoy si ya se registró ([arrival] es `null` si no hay).
class TodayAppointments {
  const TodayAppointments({required this.appointments, this.arrival});

  final List<Appointment> appointments;
  final TodayArrival? arrival;
}

/// Resultado de registrar una llegada: [created] es `false` cuando el aviso
/// ya existía y el servidor devolvió el original (200 en vez de 201).
class ArrivalResult {
  const ArrivalResult({required this.arrival, required this.created});

  final Arrival arrival;
  final bool created;
}
