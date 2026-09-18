import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// En web hay que pedirle explícitamente al adapter que mande las cookies
/// `HttpOnly` en cross-origin; sin esto el navegador no las incluye.
///
/// `dio_cookie_manager` no se usa acá: el navegador ya maneja las cookies
/// solo, y el paquete asume `dart:io` (no compila en web).
Future<void> configureCredentials(Dio dio) async {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
