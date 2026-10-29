import '../../../core/network/api_exception.dart';
import '../models/doctor_shift.dart';
import '../models/doctor_shift_number.dart';

abstract class DoctorShiftRepository {
  Future<List<DoctorShift>> getDoctorShifts({required DateTime date});

  Future<DoctorShiftNumbersResponse> getDoctorShiftNumbers({
    required int shiftId,
    bool? llegada,
    String? orden,
    String? sentido,
  });
}

class DoctorShiftValidationException extends ApiException {
  const DoctorShiftValidationException([super.message]);

  String get code => 'VALIDACION';
}

class DoctorShiftUnauthorizedException extends ApiException {
  const DoctorShiftUnauthorizedException([
    super.message =
        'Tu sesión no es válida. Ingresá de nuevo para continuar.',
  ]);

  String get code => 'TOKEN_INVALIDO';
}

class DoctorShiftNotFoundException extends ApiException {
  const DoctorShiftNotFoundException([
    super.message =
        'No encontramos ese turno. Probá con otra fecha o volvé a intentarlo.',
  ]);

  String get code => 'NO_ENCONTRADO';
}
