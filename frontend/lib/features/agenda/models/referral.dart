import '../../especialidades/models/specialty.dart';
import 'agenda_time.dart';

/// Un pase disponible del socio (`PaseDTO` de
/// `GET /api/socios/me/pases/disponibles`).
/// También lo usa la respuesta del resultado de consulta del médico.
///
/// [issuedAt] es un instante (el servidor manda el offset); [expiresOn] es una
/// fecha local de Uruguay, una clave de día en UTC sin hora. Una clave de más
/// en el JSON se ignora; una que falta o con otro tipo tira `TypeError`, y una
/// fecha mal escrita `FormatException`.
class Referral {
  const Referral({
    required this.id,
    required this.specialty,
    required this.issuedAt,
    required this.expiresOn,
  });

  factory Referral.fromJson(Map<String, dynamic> json) => Referral(
    id: json['id'] as int,
    specialty: Specialty.fromJson(
      json['especialidadDestino'] as Map<String, dynamic>,
    ),
    issuedAt: DateTime.parse(json['emitidoEn'] as String),
    expiresOn: parseApiDate(json['venceEl'] as String),
  );

  final int id;

  /// La especialidad a la que habilita el pase (`especialidadDestino`).
  final Specialty specialty;
  final DateTime issuedAt;
  final DateTime expiresOn;
}
