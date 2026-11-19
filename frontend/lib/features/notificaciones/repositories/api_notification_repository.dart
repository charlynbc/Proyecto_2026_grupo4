import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/app_notification_page.dart';
import '../models/notification_query.dart';
import 'notification_repository.dart';

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._dio);

  final Dio _dio;

  @override
  Future<AppNotificationPage> list(NotificationQuery query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.notifications,
        queryParameters: query.toQueryParameters(),
      );
      return AppNotificationPage.fromJson(
        response.data ?? (throw const ApiException()),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  NotificationException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final code = apiCodeOf(error);
    final failure = switch ((status, code)) {
      (401, _) || (_, 'NO_AUTENTICADO') => NotificationFailure.unauthenticated,
      (403, _) || (_, 'ACCESO_DENEGADO') => NotificationFailure.forbidden,
      (400, _) || (_, 'VALIDACION') => NotificationFailure.validation,
      _ => NotificationFailure.other,
    };
    return NotificationException(failure, ApiException.fromDio(error).message);
  }
}
