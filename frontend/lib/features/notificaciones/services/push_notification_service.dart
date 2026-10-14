import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import '../../../core/network/api_routes.dart';

/// Mensaje recibido en foreground, ya reducido a lo que la UI necesita
/// mostrar.
class ForegroundPushMessage {
  const ForegroundPushMessage({required this.title, required this.body});

  final String title;
  final String body;
}

/// Encapsula las notificaciones push por FCM, solo para web. Si no hay VAPID
/// key configurada o no se está en web, [isSupported] es `false` y todos los
/// métodos son no-ops seguros: esto nunca puede romper el login ni el resto
/// de la app.
class PushNotificationService {
  PushNotificationService(this._dio, {String? vapidKey})
    : _vapidKey =
          vapidKey ?? const String.fromEnvironment('FIREBASE_VAPID_KEY');

  final Dio _dio;
  final String _vapidKey;

  bool get isSupported => kIsWeb && _vapidKey.isNotEmpty;

  /// Pide permiso de notificaciones, obtiene el token de FCM y lo registra
  /// en el backend. Devuelve `true` solo si quedó efectivamente registrado.
  Future<bool> register() async {
    if (!isSupported) return false;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return false;
      final token = await messaging.getToken(vapidKey: _vapidKey);
      if (token == null) return false;
      await _dio.post(ApiRoutes.pocPushRegistration, data: {'fid': token});
      return true;
    } catch (e) {
      debugPrint('PushNotificationService.register falló: $e');
      return false;
    }
  }

  /// Mensajes recibidos mientras la app está en foreground. Si no es
  /// soportado, un stream vacío.
  Stream<ForegroundPushMessage> get foregroundMessages {
    if (!isSupported) return const Stream.empty();
    return FirebaseMessaging.onMessage.map(
      (message) => ForegroundPushMessage(
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
      ),
    );
  }
}
