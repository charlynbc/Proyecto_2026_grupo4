import '../../../core/network/api_exception.dart';
import '../../historia_clinica/models/medical_history_entry.dart';

abstract class DoctorPatientHistoryRepository {
  Future<List<MedicalHistoryEntry>> history(int socioId);
}

enum DoctorPatientHistoryFailure {
  validation,
  forbidden,
  conflictOfInterest,
  notFound,
}

class DoctorPatientHistoryException extends ApiException {
  const DoctorPatientHistoryException(this.failure, [super.message]);

  final DoctorPatientHistoryFailure failure;
}
