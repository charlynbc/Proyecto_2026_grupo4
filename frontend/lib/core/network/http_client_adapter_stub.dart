import 'package:dio/dio.dart';

/// En Android el adapter por defecto de dio (`IOHttpClientAdapter`) ya manda
/// las cookies que el `CookieManager` del sistema tenga guardadas; no hace
/// falta tocar nada acá.
void configureCredentials(Dio dio) {}
