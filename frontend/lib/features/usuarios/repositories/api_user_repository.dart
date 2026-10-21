import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/new_user.dart';
import '../models/user_filters.dart';
import '../models/user_page.dart';
import 'user_repository.dart';

/// Implementación real de [UserRepository] (contrato #11 y #12). Los errores
/// se distinguen por `code`, nunca por el texto del mensaje.
class ApiUserRepository implements UserRepository {
  ApiUserRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> createUser(NewUser user) async {
    try {
      await _dio.post<void>(ApiRoutes.users, data: user.toJson());
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      throw switch (apiCodeOf(e)) {
        'CI_INVALIDA' => InvalidCiException(error.message),
        'DATOS_PERSONA_DISCORDANTES' => MismatchedPersonDataException(
          error.message,
        ),
        'SOCIO_DUPLICADO' => DuplicateMemberException(error.message),
        'EMPLEADO_DUPLICADO' => DuplicateStaffException(error.message),
        _ => error,
      };
    }
  }

  @override
  Future<UserPage> listUsers(UserFilters filters) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.users,
        queryParameters: filters.toQueryParameters(),
      );
      return UserPage.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
