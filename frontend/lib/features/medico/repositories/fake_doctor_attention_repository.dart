import '../../../core/utils/uruguay_time.dart';
import '../../agenda/models/agenda_time.dart';
import '../models/doctor_attention.dart';
import '../models/doctor_attention_query.dart';
import 'doctor_attention_repository.dart';

/// Implementación en memoria para `USE_FAKES=true`.
///
/// Las fechas de las atenciones son relativas a "hoy" en Uruguay (según
/// [clock]), así la pantalla de Atenciones no abre vacía con el período por
/// defecto, que va del primer día del mes hasta hoy. Dos atenciones son de
/// hoy, una de hace 3 días y una de hace 40 días, que queda siempre fuera de
/// ese período.
class FakeDoctorAttentionRepository implements DoctorAttentionRepository {
  FakeDoctorAttentionRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Duration latency;
  final DateTime Function() _clock;
  static Map<String, dynamic> specialty(int id, String name) => {
    'id': id,
    'nombre': name,
    'requierePase': id != 1,
  };
  static DoctorAttention entry(
    int id,
    DateTime date,
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
    'fechaAtencion': formatApiDate(date),
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
              'emitidoEn': '${formatApiDate(date)}T09:41:00-03:00',
              // Vence 90 días después, como en el ejemplo del contrato.
              'venceEl': formatApiDate(date.add(const Duration(days: 90))),
            },
          ]
        : [],
  });
  late final List<DoctorAttention> _items = _buildItems();

  List<DoctorAttention> _buildItems() {
    final now = UruguayTime.toUruguay(_clock());
    final today = DateTime.utc(now.year, now.month, now.day);
    DateTime daysAgo(int days) => today.subtract(Duration(days: days));
    return [
      entry(
        5530,
        daysAgo(0),
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
        daysAgo(3),
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
        daysAgo(40),
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
        daysAgo(0),
        23,
        '11111111',
        'Ana',
        'Pérez',
        1,
        'Medicina General',
        'Gripe',
      ),
    ];
  }

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
