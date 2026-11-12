import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../../historia_clinica/models/medical_history_entry.dart';
import 'doctor_patient_history_repository.dart';

class ApiDoctorPatientHistoryRepository
    implements DoctorPatientHistoryRepository {
  ApiDoctorPatientHistoryRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<MedicalHistoryEntry>> history(int socioId) async {
    if (socioId <= 0) {
      throw const DoctorPatientHistoryException(
        DoctorPatientHistoryFailure.validation,
        'No pudimos identificar al paciente. Volvé a Mis turnos e intentá de nuevo.',
      );
    }

    return _request(() async {
      final response = await _dio.get<dynamic>(
        ApiRoutes.doctorPatientMedicalHistory(socioId),
      );
      final data = response.data;
      if (data is! List) throw const ApiException();
      return [
        for (final item in data)
          MedicalHistoryEntry.fromJson(item as Map<String, dynamic>),
      ];
    });
  }

  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  ApiException _mapError(DioException error) {
    return switch ((error.response?.statusCode, apiCodeOf(error))) {
      (400, 'VALIDACION') => const DoctorPatientHistoryException(
        DoctorPatientHistoryFailure.validation,
        'No pudimos identificar al paciente. Volvé a Mis turnos e intentá de nuevo.',
      ),
      (403, 'ACCESO_DENEGADO') => const DoctorPatientHistoryException(
        DoctorPatientHistoryFailure.forbidden,
        'Tu cuenta no tiene permiso para consultar historias clínicas.',
      ),
      (403, 'CONFLICTO_DE_INTERES') => const DoctorPatientHistoryException(
        DoctorPatientHistoryFailure.conflictOfInterest,
        'No podés consultar tu propia historia clínica desde la cuenta de médico.',
      ),
      (404, 'NO_ENCONTRADO') => const DoctorPatientHistoryException(
        DoctorPatientHistoryFailure.notFound,
        'No podés ver la historia clínica de este paciente en este momento. Solo está disponible mientras tengas con él una consulta agendada que no haya terminado.',
      ),
      _ => ApiException.fromDio(error),
    };
  }
}
