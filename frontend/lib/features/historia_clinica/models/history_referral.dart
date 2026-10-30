import '../../agenda/models/agenda_time.dart';
import '../../especialidades/models/specialty.dart';

/// Un pase emitido en una atención de la historia clínica del socio.
class HistoryReferral {
  HistoryReferral.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      specialty = Specialty.fromJson(
        json['especialidad'] as Map<String, dynamic>,
      ),
      issuedAt = json['emitidoEn'] as String,
      expiresOn = parseApiDate(json['venceEl'] as String);

  final int id;
  final Specialty specialty;

  /// Texto ISO 8601 original, conservando el offset enviado por el servidor.
  final String issuedAt;

  /// Clave de día sin desplazamiento de zona horaria.
  final DateTime expiresOn;
}
