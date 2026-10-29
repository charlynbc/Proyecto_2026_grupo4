import '../models/medical_history_entry.dart';
import '../models/medical_history_query.dart';
import 'medical_history_repository.dart';

/// Historia clínica ficticia propia, sin base compartida ni solicitudes HTTP.
class FakeMedicalHistoryRepository implements MedicalHistoryRepository {
  FakeMedicalHistoryRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;

  final List<MedicalHistoryEntry> _entries = [
    MedicalHistoryEntry.fromJson({
      'idAtencion': 10,
      'fechaAtencion': '2026-09-24',
      'medicoId': 4,
      'medicoNombre': 'Diego',
      'medicoApellido': 'Viera',
      'especialidad': {
        'id': 3,
        'nombre': 'Cardiología',
        'requierePase': true,
      },
      'afeccion': 'gripe',
      'tratamiento': null,
      'observaciones': null,
      'pases': <dynamic>[],
    }),
    MedicalHistoryEntry.fromJson({
      'idAtencion': 11,
      'fechaAtencion': '2026-09-10',
      'medicoId': 8,
      'medicoNombre': 'Laura',
      'medicoApellido': 'Pérez',
      'especialidad': {
        'id': 5,
        'nombre': 'Traumatología',
        'requierePase': true,
      },
      'afeccion': 'Dolor lumbar',
      'tratamiento': 'Reposo durante tres días',
      'observaciones': 'Control de evolución',
      'pases': <dynamic>[],
    }),
    MedicalHistoryEntry.fromJson({
      'idAtencion': 12,
      'fechaAtencion': '2026-10-02',
      'medicoId': 4,
      'medicoNombre': 'Diego',
      'medicoApellido': 'Viera',
      'especialidad': {
        'id': 3,
        'nombre': 'Cardiología',
        'requierePase': true,
      },
      'afeccion': 'Control cardiovascular',
      'tratamiento': 'Reposo relativo y control',
      'observaciones': 'Continuar seguimiento',
      'pases': [
        {
          'id': 7,
          'especialidad': {
            'id': 5,
            'nombre': 'Traumatología',
            'requierePase': true,
          },
          'emitidoEn': '2026-10-02T10:00:00-03:00',
          'venceEl': '2026-12-23',
        },
        {
          'id': 8,
          'especialidad': {
            'id': 6,
            'nombre': 'Dermatología',
            'requierePase': true,
          },
          'emitidoEn': '2026-10-02T10:00:00-03:00',
          'venceEl': '2026-11-01',
        },
      ],
    }),
    MedicalHistoryEntry.fromJson({
      'idAtencion': 13,
      'fechaAtencion': '2026-08-20',
      'medicoId': 9,
      'medicoNombre': 'Ana',
      'medicoApellido': 'Silva',
      'especialidad': {
        'id': 6,
        'nombre': 'Dermatología',
        'requierePase': true,
      },
      'afeccion': 'Reposo mencionado en afección',
      'tratamiento': 'Crema por la noche',
      'observaciones': 'Reposo mencionado en observaciones',
      'pases': <dynamic>[],
    }),
  ];

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) async {
    await Future<void>.delayed(latency);
    final from = query.from;
    final to = query.to;
    final search = query.text?.trim().toLowerCase() ?? '';
    final matches = [
      for (final entry in _entries)
        if ((from == null || !entry.attendedOn.isBefore(from)) &&
            (to == null || !entry.attendedOn.isAfter(to)) &&
            (query.specialtyId == null ||
                entry.specialty.id == query.specialtyId) &&
            (query.doctorId == null || entry.doctorId == query.doctorId) &&
            (search.isEmpty ||
                (entry.treatment?.toLowerCase().contains(search) ?? false)))
          entry,
    ];

    // Ordena una lista nueva para conservar intactos los datos originales.
    matches.sort((a, b) {
      final primary = switch (query.order) {
        MedicalHistoryOrder.date => a.attendedOn.compareTo(b.attendedOn),
        MedicalHistoryOrder.specialty =>
          a.specialty.name.compareTo(b.specialty.name),
      };
      final comparison = primary != 0 ? primary : a.id.compareTo(b.id);
      return query.direction == MedicalHistoryDirection.ascending
          ? comparison
          : -comparison;
    });
    return matches;
  }

  @override
  Future<MedicalHistoryEntry> get(int id) async {
    await Future<void>.delayed(latency);
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    throw const MedicalHistoryNotFoundException();
  }
}
