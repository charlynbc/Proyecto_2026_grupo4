import '../../agenda/models/agenda_time.dart';
import '../../especialidades/models/specialty.dart';

/// La situación de un pase emitido, tal como la calcula el servidor.
enum ReferralStatus {
  available('DISPONIBLE', 'Disponible'),
  used('UTILIZADO', 'Utilizado'),
  expired('VENCIDO', 'Vencido');

  const ReferralStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Un valor desconocido tira `FormatException`, en vez de mostrarse mal en
  /// silencio (decisión del cliente, no del contrato).
  static ReferralStatus fromApi(String value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    throw FormatException('Situación de pase desconocida', value);
  }
}

/// El socio al que se le emitió el pase.
class IssuedReferralPatient {
  const IssuedReferralPatient({
    required this.id,
    required this.ci,
    required this.name,
    required this.lastName,
  });

  factory IssuedReferralPatient.fromJson(Map<String, dynamic> json) =>
      IssuedReferralPatient(
        id: json['id'] as int,
        ci: json['ci'] as String,
        name: json['nombre'] as String,
        lastName: json['apellido'] as String,
      );

  final int id;
  final String ci;
  final String name;
  final String lastName;

  String get fullName => '$name $lastName';
}

/// Un pase que emitió el médico (`PaseEmitidoDTO`, contrato #43).
class IssuedReferral {
  const IssuedReferral({
    required this.id,
    required this.patient,
    required this.destination,
    required this.issuedAt,
    required this.expiresOn,
    required this.status,
  });

  /// [issuedAt] es un instante (se muestra en hora de Uruguay) y [expiresOn]
  /// una clave de día. La situación la calcula el servidor: no se recalcula.
  factory IssuedReferral.fromJson(Map<String, dynamic> json) => IssuedReferral(
    id: json['id'] as int,
    patient: IssuedReferralPatient.fromJson(
      json['paciente'] as Map<String, dynamic>,
    ),
    destination: Specialty.fromJson(
      json['especialidadDestino'] as Map<String, dynamic>,
    ),
    issuedAt: DateTime.parse(json['emitidoEn'] as String),
    expiresOn: parseApiDate(json['venceEl'] as String),
    status: ReferralStatus.fromApi(json['situacion'] as String),
  );

  final int id;
  final IssuedReferralPatient patient;
  final Specialty destination;
  final DateTime issuedAt;
  final DateTime expiresOn;
  final ReferralStatus status;
}
