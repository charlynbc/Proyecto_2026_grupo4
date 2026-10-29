import '../../agenda/models/agenda_time.dart';
import '../../especialidades/models/specialty.dart';
import 'history_referral.dart';

/// Una atención registrada en la historia clínica del socio.
class MedicalHistoryEntry {
  MedicalHistoryEntry.fromJson(Map<String, dynamic> json)
    : id = json['idAtencion'] as int,
      attendedOn = parseApiDate(json['fechaAtencion'] as String),
      doctorId = json['medicoId'] as int,
      doctorFirstName = json['medicoNombre'] as String,
      doctorLastName = json['medicoApellido'] as String,
      specialty = Specialty.fromJson(
        json['especialidad'] as Map<String, dynamic>,
      ),
      condition = json['afeccion'] as String,
      treatment = json['tratamiento'] as String?,
      observations = json['observaciones'] as String?,
      referrals = List<HistoryReferral>.unmodifiable(
        (json['pases'] as List<dynamic>).map(
          (item) => HistoryReferral.fromJson(item as Map<String, dynamic>),
        ),
      );

  final int id;

  /// Clave de día sin desplazamiento de zona horaria.
  final DateTime attendedOn;
  final int doctorId;
  final String doctorFirstName;
  final String doctorLastName;
  final Specialty specialty;
  final String condition;
  final String? treatment;
  final String? observations;
  final List<HistoryReferral> referrals;

  String get doctorFullName => '$doctorFirstName $doctorLastName';
}
