import '../../../core/network/api_exception.dart';
import '../models/issued_referral.dart';
import '../models/issued_referral_query.dart';

/// Los pases que emitió el médico autenticado (RF-26).
abstract class IssuedReferralRepository {
  /// Los pases que cumplen [query]. Sin resultados: lista vacía.
  Future<List<IssuedReferral>> list(IssuedReferralQuery query);
}

/// Por qué no se pudo consultar. Los demás rechazos (`VALIDACION`,
/// `ORDEN_INVALIDO`, `SENTIDO_INVALIDO`) no los provoca el cliente y caen en
/// el mensaje genérico.
enum IssuedReferralFailure { forbidden }

class IssuedReferralException extends ApiException {
  const IssuedReferralException(this.failure, [super.message]);

  final IssuedReferralFailure failure;
}

/// El texto que ve quien no es médico (`ACCESO_DENEGADO`, 403).
const String kIssuedReferralsForbiddenMessage =
    'Tu cuenta no tiene permiso para consultar pases.';
