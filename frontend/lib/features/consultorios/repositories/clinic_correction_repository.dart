import '../../../core/network/api_exception.dart';
import '../models/clinic.dart';

abstract class ClinicCorrectionRepository {
  Future<Clinic> correct(int id, {String? name, String? location});
}

enum ClinicCorrectionFailure { notFound, duplicate, validation, other }

class ClinicCorrectionException extends ApiException {
  const ClinicCorrectionException(this.failure, [super.message]);

  final ClinicCorrectionFailure failure;
}
