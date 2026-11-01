import '../../agenda/models/referral.dart';

/// Vigencia que el servidor aplica a un pase cuando no se indica otra.
const int kDefaultReferralValidityDays = 90;

/// Rango de días de vigencia que acepta el servidor para un pase.
const int kMinReferralValidityDays = 1;
const int kMaxReferralValidityDays = 365;

/// Cómo terminó una consulta (RF-23).
enum ConsultationOutcome {
  attended('ATENDIDA'),
  noShow('NO_SE_PRESENTO');

  const ConsultationOutcome(this.apiValue);

  final String apiValue;

  /// El resultado de un `estado` del servidor. Uno desconocido tira
  /// `FormatException`: no se clasifica mal en silencio.
  static ConsultationOutcome fromApi(String value) {
    for (final outcome in values) {
      if (outcome.apiValue == value) return outcome;
    }
    throw FormatException('Resultado desconocido', value);
  }
}

/// Un pase a emitir junto con la atención (`PaseNuevoDTO`).
class ReferralRequest {
  const ReferralRequest({
    required this.specialtyId,
    this.validityDays = kDefaultReferralValidityDays,
  });

  final int specialtyId;
  final int validityDays;

  Map<String, Object?> toJson() => {
    'especialidadDestinoId': specialtyId,
    'vigenciaDias': validityDays,
  };
}

/// El cuerpo de `POST /api/medico/consultas/{id}/resultado`.
class AppointmentResultRequest {
  const AppointmentResultRequest({
    required this.outcome,
    this.condition,
    this.treatment,
    this.notes,
    this.referrals = const [],
  });

  final ConsultationOutcome outcome;
  final String? condition;
  final String? treatment;
  final String? notes;
  final List<ReferralRequest> referrals;

  /// Con [ConsultationOutcome.noShow] va solo `resultado`, aunque haya texto
  /// cargado. Con [ConsultationOutcome.attended] se omiten tratamiento,
  /// observaciones y pases vacíos.
  Map<String, Object?> toJson() {
    if (outcome == ConsultationOutcome.noShow) {
      return {'resultado': outcome.apiValue};
    }
    return {
      'resultado': outcome.apiValue,
      'afeccion': ?condition,
      if (treatment != null && treatment!.isNotEmpty) 'tratamiento': treatment,
      if (notes != null && notes!.isNotEmpty) 'observaciones': notes,
      if (referrals.isNotEmpty)
        'pases': [for (final referral in referrals) referral.toJson()],
    };
  }
}

/// La respuesta del servidor al registrar el resultado (`ResultadoConsultaDTO`).
/// Una clave que falta o con otro tipo tira `TypeError`, y un valor mal
/// escrito `FormatException`.
class AppointmentResult {
  const AppointmentResult({
    required this.appointmentId,
    required this.outcome,
    required this.attentionId,
    required this.registeredAt,
    required this.referrals,
  });

  factory AppointmentResult.fromJson(Map<String, dynamic> json) =>
      AppointmentResult(
        appointmentId: json['consultaId'] as int,
        outcome: ConsultationOutcome.fromApi(json['estado'] as String),
        attentionId: json['atencionId'] as int?,
        registeredAt: DateTime.parse(json['registradoEn'] as String),
        referrals: [
          for (final item in json['pases'] as List<dynamic>)
            Referral.fromJson(item as Map<String, dynamic>),
        ],
      );

  final int appointmentId;
  final ConsultationOutcome outcome;

  /// `null` cuando el paciente no se presentó.
  final int? attentionId;
  final DateTime registeredAt;
  final List<Referral> referrals;
}
