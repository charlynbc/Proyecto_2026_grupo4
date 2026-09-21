import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

/// En Android el adapter nativo de dio no persiste cookies entre requests,
/// así que sin esto la cookie `HttpOnly` del refresh token se pierde apenas
/// termina la primera request y la sesión no sobrevive ni a la siguiente
/// llamada.
Future<void> configureCredentials(Dio dio) async {
  final supportDir = await getApplicationSupportDirectory();
  final cookieJar = PersistCookieJar(
    storage: FileStorage('${supportDir.path}/.cookies/'),
  );
  dio.interceptors.add(CookieManager(cookieJar));
}
