import '../../../core/network/api_exception.dart';
import '../models/doctor_attention.dart';
import '../models/doctor_attention_query.dart';

abstract class DoctorAttentionRepository {
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query);
  Future<DoctorAttention> get(int id);
}

enum DoctorAttentionFailure { validation, forbidden, notFound }

class DoctorAttentionException extends ApiException {
  const DoctorAttentionException(this.failure, super.message);
  final DoctorAttentionFailure failure;
}

const attentionValidationMessage =
    'Revisá los filtros: las dos fechas son obligatorias y la fecha desde no puede ser posterior a la fecha hasta.';
const attentionForbiddenMessage =
    'Tu cuenta no tiene permiso para consultar atenciones.';
const attentionNotFoundMessage =
    'No encontramos esta atención entre las tuyas.';
