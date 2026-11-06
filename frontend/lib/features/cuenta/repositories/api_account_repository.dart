import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/account.dart';
import 'account_repository.dart';

/// Implementación real de [AccountRepository] (contrato, fila 46). Una
/// respuesta mal formada, o con un rol desconocido, se vuelve el error
/// genérico: no se muestra una cuenta a medias.
class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._dio);

  final Dio _dio;

  @override
  Future<Account> get() async {
    try {
      // Como `Object?`: con otro tipo, una respuesta que no es un objeto
      // haría fallar el cast dentro de dio como si fuera la conexión.
      final response = await _dio.get<Object?>(ApiRoutes.accountMe);
      final data = response.data;
      if (data is! Map<String, dynamic>) throw const ApiException();
      return Account.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }
}
