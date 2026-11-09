import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/account.dart';
import '../models/account_changes.dart';
import 'account_repository.dart';

/// Implementación real de [AccountRepository] (contrato, filas 46 y 47). Una
/// respuesta mal formada, o con un rol desconocido, se vuelve el error
/// genérico: no se muestra una cuenta a medias.
class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._dio);

  final Dio _dio;

  @override
  Future<Account> get() =>
      _readAccount(() => _dio.get<Object?>(ApiRoutes.accountMe));

  @override
  Future<Account> update(AccountChanges changes) async {
    if (changes.isEmpty) throw const AccountValidationException.empty();
    return _readAccount(
      () => _dio.patch<Object?>(ApiRoutes.accountMe, data: changes.toJson()),
    );
  }

  Future<Account> _readAccount(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      // Como `Object?`: con otro tipo, una respuesta que no es un objeto
      // haría fallar el cast dentro de dio como si fuera la conexión.
      final response = await request();
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const ApiException();
      return Account.fromJson(data);
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      final data = e.response?.data;
      if (e.response?.statusCode == 400 &&
          data is Map &&
          data['code'] == 'VALIDACION') {
        throw AccountValidationException(error.message);
      }
      throw error;
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }
}
