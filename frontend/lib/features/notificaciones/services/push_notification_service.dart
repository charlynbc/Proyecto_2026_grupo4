import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/push_tap.dart';

/// Mensaje recibido en primer plano, ya reducido a lo que la UI necesita
/// mostrar. [tap] es a dónde lleva si el socio lo toca ("Ver").
class ForegroundPushMessage {
  const ForegroundPushMessage({
    required this.title,
    required this.body,
    this.tap = const PushTap(type: ''),
  });

  final String title;
  final String body;
  final PushTap tap;
}

/// Lo que se necesita del SDK de notificaciones push, y nada más: el permiso,
/// el token, su renovación, los mensajes en primer plano y los toques sobre una
/// notificación. Registrar el token en el servidor es cosa de
/// `DeviceRepository`.
///
/// Solo existe push en Android (RNF-23): en la web y con `USE_FAKES` la
/// implementación es [NoopPushNotificationService] (o su variante
/// [SimulatedPushNotificationService], que deja simular un toque a mano).
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

  /// El push que el socio tocó para abrir la app cuando estaba cerrada, o
  /// `null` si se abrió de otra forma. Firebase lo entrega una sola vez. Nunca
  /// propaga un error.
  Future<PushTap?> getInitialTap();

  /// Los push que el socio toca con la app abierta en segundo plano.
  Stream<PushTap> get taps;

  /// Borra el token de Firebase de este dispositivo: el servidor lo deshabilita
  /// en el próximo envío (Firebase responde que ya no existe). Se usa cuando la
  /// sesión cae por vencimiento y ya no hay con qué llamar a la baja. Tiene un
  /// tope de 3 segundos y nunca propaga un error ni escribe el token.
  Future<void> deleteToken();
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

  @override
  Future<PushTap?> getInitialTap() async => null;

  @override
  Stream<PushTap> get taps => const Stream.empty();

  @override
  Future<void> deleteToken() async {}
}

/// El servicio de `USE_FAKES`: no toca Firebase, pero deja simular a mano un
/// mensaje en primer plano o el toque de un push (para probar la navegación en
/// Chrome, donde no hay push). Lo usa la pantalla de prueba de `/debug/push`.
class SimulatedPushNotificationService extends NoopPushNotificationService {
  SimulatedPushNotificationService();

  final StreamController<PushTap> _taps = StreamController<PushTap>.broadcast();
  final StreamController<ForegroundPushMessage> _foreground =
      StreamController<ForegroundPushMessage>.broadcast();
  PushTap? _initialTap;

  /// Simula que el socio tocó un push con la app en segundo plano.
  void simulateTap(PushTap tap) => _taps.add(tap);

  /// Simula un push que llega con la app abierta.
  void simulateForeground(ForegroundPushMessage message) =>
      _foreground.add(message);

  /// Deja un toque para que [getInitialTap] lo entregue (una sola vez).
  void queueInitialTap(PushTap tap) => _initialTap = tap;

  @override
  Stream<PushTap> get taps => _taps.stream;

  @override
  Stream<ForegroundPushMessage> get foregroundMessages => _foreground.stream;

  @override
  Future<PushTap?> getInitialTap() async {
    final tap = _initialTap;
    _initialTap = null;
    return tap;
  }
}

/// Implementación sobre `firebase_messaging`. No toca el SDK hasta que se
/// usa un método, así que construirla no exige Firebase inicializado.
///
/// [onMessage], [onMessageOpenedApp] e [initialMessage] existen para los tests:
/// por defecto usan los del SDK.
class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService({
    this._messaging,
    this._onMessage,
    this._onMessageOpenedApp,
    this._initialMessage,
  });

  /// Cuánto se espera a que Firebase borre el token: si no responde, se sigue.
  static const _deleteTokenTimeout = Duration(seconds: 3);

  final FirebaseMessaging? _messaging;
  final Stream<RemoteMessage>? _onMessage;
  final Stream<RemoteMessage>? _onMessageOpenedApp;
  final Future<RemoteMessage?> Function()? _initialMessage;

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
          tap: PushTap.fromData(message.data),
        ),
      );

  @override
  Future<PushTap?> getInitialTap() async {
    try {
      final message = await (_initialMessage ?? _sdk.getInitialMessage)();
      return message == null ? null : PushTap.fromData(message.data);
    } catch (e) {
      debugPrint('FirebasePushNotificationService.getInitialTap falló: $e');
      return null;
    }
  }

  @override
  Stream<PushTap> get taps =>
      (_onMessageOpenedApp ?? FirebaseMessaging.onMessageOpenedApp).map(
        (message) => PushTap.fromData(message.data),
      );

  @override
  Future<void> deleteToken() async {
    try {
      await _sdk.deleteToken().timeout(_deleteTokenTimeout);
    } catch (e) {
      debugPrint('FirebasePushNotificationService.deleteToken falló: $e');
    }
  }
}
