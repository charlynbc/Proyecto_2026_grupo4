import '../../agenda/models/agenda_time.dart';
import '../../../core/utils/uruguay_time.dart';

enum DoctorAttentionOrder { date, patientLastName }

enum DoctorAttentionDirection { ascending, descending }

String normalizePatientSearch(String value) {
  final trimmed = value.trim();
  final digits = trimmed.replaceAll(RegExp(r'[.\-\s]'), '');
  return RegExp(r'^\d+$').hasMatch(digits) ? digits : trimmed;
}

class DoctorAttentionQuery {
  const DoctorAttentionQuery({
    required this.from,
    required this.to,
    this.patientText = '',
    this.specialtyId,
    this.order = DoctorAttentionOrder.date,
    this.direction = DoctorAttentionDirection.descending,
  });
  factory DoctorAttentionQuery.initial() {
    final today = UruguayTime.today();
    return DoctorAttentionQuery(
      from: DateTime.utc(today.year, today.month),
      to: today,
    );
  }
  final DateTime from, to;
  final String patientText;
  final int? specialtyId;
  final DoctorAttentionOrder order;
  final DoctorAttentionDirection direction;
  Map<String, dynamic> toQueryParameters() => {
    'fechaDesde': formatApiDate(from),
    'fechaHasta': formatApiDate(to),
    if (normalizePatientSearch(patientText).isNotEmpty)
      'paciente': normalizePatientSearch(patientText),
    if (specialtyId != null) 'especialidadId': specialtyId,
    'orden': order == DoctorAttentionOrder.date ? 'fecha' : 'apellido',
    'sentido': direction == DoctorAttentionDirection.ascending ? 'asc' : 'desc',
  };
}
