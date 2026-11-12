import '../models/doctor_attention.dart';
import '../models/doctor_attention_query.dart';
import 'doctor_attention_repository.dart';

class FakeDoctorAttentionRepository implements DoctorAttentionRepository {
  FakeDoctorAttentionRepository({
    this.latency = const Duration(milliseconds: 300),
  });
  final Duration latency;
  static Map<String, dynamic> specialty(int id, String name) => {
    'id': id,
    'nombre': name,
    'requierePase': id != 1,
  };
  static DoctorAttention entry(
    int id,
    String date,
    int patientId,
    String ci,
    String name,
    String surname,
    int specialtyId,
    String specialtyName,
    String condition, {
    bool referral = false,
  }) => DoctorAttention.fromJson({
    'idAtencion': id,
    'fechaAtencion': date,
    'paciente': {
      'id': patientId,
      'ci': ci,
      'nombre': name,
      'apellido': surname,
    },
    'especialidad': specialty(specialtyId, specialtyName),
    'afeccion': condition,
    'tratamiento': referral ? 'Control de dieta y medicación indicada' : null,
    'observaciones': null,
    'pases': referral
        ? [
            {
              'id': 78,
              'especialidad': specialty(4, 'Nutrición'),
              'emitidoEn': '2026-10-20T09:41:00-03:00',
              'venceEl': '2027-01-18',
            },
          ]
        : [],
  });
  static final _items = [
    entry(
      5530,
      '2026-10-20',
      21,
      '45678911',
      'Lucía',
      'Fernández',
      3,
      'Cardiología',
      'Hipertensión arterial leve',
      referral: true,
    ),
    entry(
      5531,
      '2026-10-14',
      22,
      '50123456',
      'Bruno',
      'Acosta',
      1,
      'Medicina General',
      'Control de rutina',
    ),
    entry(
      5532,
      '2026-09-30',
      21,
      '45678911',
      'Lucía',
      'Fernández',
      3,
      'Cardiología',
      'Control cardiovascular',
    ),
    entry(
      5533,
      '2026-10-20',
      23,
      '11111111',
      'Ana',
      'Pérez',
      1,
      'Medicina General',
      'Gripe',
    ),
  ];
  @override
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query) async {
    await Future<void>.delayed(latency);
    if (query.from.isAfter(query.to) || query.patientText.length > 100) {
      throw const DoctorAttentionException(
        DoctorAttentionFailure.validation,
        attentionValidationMessage,
      );
    }
    final search = normalizePatientSearch(query.patientText).toLowerCase();
    final items = _items
        .where(
          (a) =>
              !a.attendedOn.isBefore(query.from) &&
              !a.attendedOn.isAfter(query.to) &&
              (query.specialtyId == null ||
                  a.specialty.id == query.specialtyId) &&
              (a.patient.ci.toLowerCase().contains(search) ||
                  a.patient.lastName.toLowerCase().contains(search)),
        )
        .toList();
    final sign = query.direction == DoctorAttentionDirection.ascending ? 1 : -1;
    items.sort((a, b) {
      if (query.order == DoctorAttentionOrder.date) {
        final date = a.attendedOn.compareTo(b.attendedOn);
        return sign * (date == 0 ? a.id.compareTo(b.id) : date);
      }
      final name = a.patient.lastName.toLowerCase().compareTo(
        b.patient.lastName.toLowerCase(),
      );
      if (name != 0) return sign * name;
      final date = b.attendedOn.compareTo(a.attendedOn);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
    return items;
  }

  @override
  Future<DoctorAttention> get(int id) async {
    await Future<void>.delayed(latency);
    if (id <= 0) {
      throw const DoctorAttentionException(
        DoctorAttentionFailure.validation,
        attentionValidationMessage,
      );
    }
    for (final item in _items) {
      if (item.id == id) return item;
    }
    throw const DoctorAttentionException(
      DoctorAttentionFailure.notFound,
      attentionNotFoundMessage,
    );
  }
}
