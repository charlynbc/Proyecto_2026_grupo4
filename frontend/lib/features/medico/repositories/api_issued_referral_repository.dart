import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/issued_referral.dart';
import '../models/issued_referral_query.dart';
import 'issued_referral_repository.dart';

/// Implementación real de [IssuedReferralRepository] (`GET
/// /api/medico/pases`, contrato #43). La situación de cada pase la calcula el
/// servidor y se muestra tal cual.
class ApiIssuedReferralRepository implements IssuedReferralRepository {
  ApiIssuedReferralRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<IssuedReferral>> list(IssuedReferralQuery query) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiRoutes.doctorReferrals,
        queryParameters: query.toQueryParameters(),
      );
      final data = response.data;
      if (data is! List) throw const ApiException();
      return [
        for (final item in data)
          IssuedReferral.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  ApiException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final code = apiCodeOf(error);
    if (status == 403 || code == 'ACCESO_DENEGADO') {
      return const IssuedReferralException(
        IssuedReferralFailure.forbidden,
        kIssuedReferralsForbiddenMessage,
      );
    }
    // El cliente nunca manda un valor inválido: si el servidor lo rechaza, no
    // hay nada que el médico pueda corregir.
    if (code == 'VALIDACION' ||
        code == 'ORDEN_INVALIDO' ||
        code == 'SENTIDO_INVALIDO') {
      return const ApiException();
    }
    return ApiException.fromDio(error);
  }
}
