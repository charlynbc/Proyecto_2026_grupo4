import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import 'password_change_repository.dart';

class ApiPasswordChangeRepository implements PasswordChangeRepository {
  ApiPasswordChangeRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        ApiRoutes.authChangePassword,
        data: {'passwordActual': currentPassword, 'passwordNueva': newPassword},
      );
    } on DioException catch (error) {
      final message = ApiException.fromDio(error).message;
      final failure = switch (apiCodeOf(error)) {
        'CONTRASENA_ACTUAL_INCORRECTA' =>
          PasswordChangeFailure.wrongCurrentPassword,
        'VALIDACION' => PasswordChangeFailure.validation,
        _ => PasswordChangeFailure.other,
      };
      throw PasswordChangeException(failure, message);
    }
  }
}
