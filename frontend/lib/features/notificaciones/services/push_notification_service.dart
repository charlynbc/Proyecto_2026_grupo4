import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Mensaje recibido en primer plano, ya reducido a lo que la UI necesita
/// mostrar.
class ForegroundPushMessage {
  const ForegroundPushMessage({required this.title, required this.body});

  final String title;
  final String body;
}

/// Lo que se necesita del SDK de notificaciones push, y nada más: el permiso,
/// el token, su renovación y los mensajes en primer plano. Registrar el
/// token en el servidor es cosa de `DeviceRepository`.
///
/// Solo existe push en Android (RNF-23): en la web y con `USE_FAKES` la
/// implementación es [NoopPushNotificationService].
abstract class PushNotificationService {
  /// Pide el permiso de notificaciones (si falta) y devuelve el token de
  /// Firebase. Devuelve `null` si el socio no dio el permiso o si algo
  /// falla: nunca propaga un error, porque no puede romper el inicio de
  /// sesión.
  Future<String?> requestToken();

  /// Cada token nuevo que genera Firebase mientras la app está en uso.
  Stream<String> get tokenRefreshes;

  /// Mensajes recibidos con la app en primer plano.
  Stream<ForegroundPushMessage> get foregroundMessages;
}

/// No toca Firebase ni pide ningún permiso.
class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<String?> requestToken() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<ForegroundPushMessage> get foregroundMessages => const Stream.empty();
}

/// Implementación sobre `firebase_messaging`. No toca el SDK hasta que se
/// usa un método, así que construirla no exige Firebase inicializado.
class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService({this._messaging, this._onMessage});

  final FirebaseMessaging? _messaging;
  final Stream<RemoteMessage>? _onMessage;

  FirebaseMessaging get _sdk => _messaging ?? FirebaseMessaging.instance;

  @override
  Future<String?> requestToken() async {
    try {
      final settings = await _sdk.requestPermission();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return null;
      return await _sdk.getToken();
    } catch (e) {
      debugPrint('FirebasePushNotificationService.requestToken falló: $e');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshes => _sdk.onTokenRefresh;

  @override
  Stream<ForegroundPushMessage> get foregroundMessages =>
      (_onMessage ?? FirebaseMessaging.onMessage).map(
        (message) => ForegroundPushMessage(
          title: message.notification?.title ?? '',
          body: message.notification?.body ?? '',
        ),
      );
}
