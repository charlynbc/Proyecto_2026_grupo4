import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/account_detail.dart';
import 'user_correction_repository.dart';

/// Implementación real de [UserCorrectionRepository] (contrato, filas 68 y
/// 58). Una respuesta mal formada se vuelve el error genérico.
class ApiUserCorrectionRepository implements UserCorrectionRepository {
  ApiUserCorrectionRepository(this._dio);

  final Dio _dio;

  @override
  Future<AccountDetail> fetch(int id) async {
    _requirePositive(id);
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiRoutes.user(id));
      return AccountDetail.fromJson(
        response.data ?? (throw const FormatException()),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    } on FormatException {
      throw const UserCorrectionException(UserCorrectionFailure.other);
    } on TypeError {
      throw const UserCorrectionException(UserCorrectionFailure.other);
    }
  }

  @override
  Future<AccountDetail> correct(int id, AccountCorrection changes) async {
    _requirePositive(id);
    // El servidor rechaza un cuerpo vacío: ni se lo manda.
    if (changes.isEmpty) {
      throw const UserCorrectionException(
        UserCorrectionFailure.validation,
        'No hay cambios para guardar.',
      );
    }
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiRoutes.user(id),
        data: changes.toJson(),
      );
      return AccountDetail.fromJson(
        response.data ?? (throw const FormatException()),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    } on FormatException {
      throw const UserCorrectionException(UserCorrectionFailure.other);
    } on TypeError {
      throw const UserCorrectionException(UserCorrectionFailure.other);
    }
  }

  void _requirePositive(int id) {
    if (id <= 0) {
      throw const UserCorrectionException(
        UserCorrectionFailure.notFound,
        'No encontramos esa cuenta.',
      );
    }
  }

  /// Distingue los casos por su `code`; el mensaje es el del servidor.
  UserCorrectionException _mapError(DioException e) {
    final failure = switch (apiCodeOf(e)) {
      'USUARIO_NO_ENCONTRADO' => UserCorrectionFailure.notFound,
      'CI_INVALIDA' => UserCorrectionFailure.invalidCi,
      'CI_EN_USO' => UserCorrectionFailure.ciInUse,
      'ESPECIALIDAD_EN_USO' => UserCorrectionFailure.specialtyInUse,
      'VALIDACION' => UserCorrectionFailure.validation,
      _ => UserCorrectionFailure.other,
    };
    return UserCorrectionException(failure, ApiException.fromDio(e).message);
  }
}
