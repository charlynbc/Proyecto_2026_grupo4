import '../../agenda/models/agenda_time.dart';
import '../../especialidades/models/specialty.dart';
import '../../historia_clinica/models/history_referral.dart';

class DoctorAttentionPatient {
  DoctorAttentionPatient.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      ci = json['ci'] as String,
      name = json['nombre'] as String,
      lastName = json['apellido'] as String;
  final int id;
  final String ci, name, lastName;
  String get fullName => '$name $lastName';
}

class DoctorAttention {
  DoctorAttention.fromJson(Map<String, dynamic> json)
    : id = json['idAtencion'] as int,
      attendedOn = parseApiDate(json['fechaAtencion'] as String),
      patient = DoctorAttentionPatient.fromJson(
        json['paciente'] as Map<String, dynamic>,
      ),
      specialty = Specialty.fromJson(
        json['especialidad'] as Map<String, dynamic>,
      ),
      condition = json['afeccion'] as String,
      treatment = json['tratamiento'] as String?,
      observations = json['observaciones'] as String?,
      referrals = (json['pases'] as List)
          .map((e) => HistoryReferral.fromJson(e as Map<String, dynamic>))
          .toList();
  final int id;
  final DateTime attendedOn;
  final DoctorAttentionPatient patient;
  final Specialty specialty;
  final String condition;
  final String? treatment, observations;
  final List<HistoryReferral> referrals;
}
