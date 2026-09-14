import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// En web hay que pedirle explícitamente al adapter que mande las cookies
/// `HttpOnly` en cross-origin; sin esto el navegador no las incluye.
void configureCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}
