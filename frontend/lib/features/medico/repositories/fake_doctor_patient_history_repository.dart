import '../../historia_clinica/models/medical_history_entry.dart';
import 'doctor_patient_history_repository.dart';

class FakeDoctorPatientHistoryRepository
    implements DoctorPatientHistoryRepository {
  FakeDoctorPatientHistoryRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;

  @override
  Future<List<MedicalHistoryEntry>> history(int socioId) async {
    if (socioId <= 0) {
      throw const DoctorPatientHistoryException(
        DoctorPatientHistoryFailure.validation,
        'No pudimos identificar al paciente. Volvé a Mis turnos e intentá de nuevo.',
      );
    }

    await Future<void>.delayed(latency);

    if (socioId == 101) {
      return [
        MedicalHistoryEntry.fromJson({
          'idAtencion': 5530,
          'fechaAtencion': '2026-10-20',
          'medicoId': 17,
          'medicoNombre': 'Marta',
          'medicoApellido': 'Rodríguez',
          'especialidad': {
            'id': 3,
            'nombre': 'Cardiología',
            'requierePase': true,
          },
          'afeccion': 'Hipertensión arterial leve',
          'tratamiento': 'Control de dieta y medicación indicada',
          'observaciones': null,
          'pases': [
            {
              'id': 78,
              'especialidad': {
                'id': 4,
                'nombre': 'Nutrición',
                'requierePase': true,
              },
              'emitidoEn': '2026-10-20T09:41:00-03:00',
              'venceEl': '2027-01-18',
            },
          ],
        }),
        MedicalHistoryEntry.fromJson({
          'idAtencion': 5000,
          'fechaAtencion': '2026-09-10',
          'medicoId': 22,
          'medicoNombre': 'Laura',
          'medicoApellido': 'Pérez',
          'especialidad': {
            'id': 5,
            'nombre': 'Traumatología',
            'requierePase': true,
          },
          'afeccion': 'Dolor lumbar',
          'tratamiento': null,
          'observaciones': null,
          'pases': <Object>[],
        }),
      ];
    }

    if (socioId == 102) return [];

    throw const DoctorPatientHistoryException(
      DoctorPatientHistoryFailure.notFound,
      'No podés ver la historia clínica de este paciente en este momento. Solo está disponible mientras tengas con él una consulta agendada que no haya terminado.',
    );
  }
}
