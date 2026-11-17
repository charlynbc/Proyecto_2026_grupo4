import 'dart:async';

import 'package:agenda_medica/features/notificaciones/services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.notSupported,
      announcement: AppleNotificationSetting.notSupported,
      authorizationStatus: status,
      badge: AppleNotificationSetting.notSupported,
      carPlay: AppleNotificationSetting.notSupported,
      lockScreen: AppleNotificationSetting.notSupported,
      notificationCenter: AppleNotificationSetting.notSupported,
      showPreviews: AppleShowPreviewSetting.notSupported,
      timeSensitive: AppleNotificationSetting.notSupported,
      criticalAlert: AppleNotificationSetting.notSupported,
      sound: AppleNotificationSetting.notSupported,
      providesAppNotificationSettings: AppleNotificationSetting.notSupported,
    );

/// Un `FirebaseMessaging` que no toca la plataforma: responde lo que se le
/// indica y cuenta las llamadas.
class _FakeMessaging implements FirebaseMessaging {
  _FakeMessaging({
    this.status = AuthorizationStatus.authorized,
    this.token = 'fcm-token-1',
    this.permissionError,
  });

  final AuthorizationStatus status;
  final String? token;
  final Object? permissionError;
  final StreamController<String> refreshes =
      StreamController<String>.broadcast();
  int permissionRequests = 0;
  int tokenRequests = 0;

  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
    bool providesAppNotificationSettings = false,
  }) async {
    permissionRequests++;
    if (permissionError != null) throw permissionError!;
    return _settings(status);
  }

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    tokenRequests++;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NoopPushNotificationService', () {
    const service = NoopPushNotificationService();

    test('no pide permiso: requestToken devuelve null', () async {
      expect(await service.requestToken(), isNull);
    });

    test('los streams de renovación y de primer plano están vacíos', () async {
      expect(await service.tokenRefreshes.isEmpty, isTrue);
      expect(await service.foregroundMessages.isEmpty, isTrue);
    });
  });

  group('FirebasePushNotificationService', () {
    test(
      'con permiso otorgado pide el permiso una vez y devuelve el token',
      () async {
        final messaging = _FakeMessaging();
        final service = FirebasePushNotificationService(messaging: messaging);

        expect(await service.requestToken(), 'fcm-token-1');
        expect(messaging.permissionRequests, 1);
        expect(messaging.tokenRequests, 1);
      },
    );

    test('con permiso provisional también devuelve el token', () async {
      final service = FirebasePushNotificationService(
        messaging: _FakeMessaging(status: AuthorizationStatus.provisional),
      );

      expect(await service.requestToken(), 'fcm-token-1');
    });

    test('con permiso denegado devuelve null y no pide el token', () async {
      final messaging = _FakeMessaging(status: AuthorizationStatus.denied);
      final service = FirebasePushNotificationService(messaging: messaging);

      expect(await service.requestToken(), isNull);
      expect(messaging.tokenRequests, 0);
    });

    test('si Firebase no entrega token devuelve null', () async {
      final service = FirebasePushNotificationService(
        messaging: _FakeMessaging(token: null),
      );

      expect(await service.requestToken(), isNull);
    });

    test('si el SDK falla devuelve null y no propaga el error', () async {
      final service = FirebasePushNotificationService(
        messaging: _FakeMessaging(
          permissionError: StateError('sin configuración'),
        ),
      );

      expect(await service.requestToken(), isNull);
    });

    test('tokenRefreshes entrega cada token nuevo de Firebase', () async {
      final messaging = _FakeMessaging();
      final service = FirebasePushNotificationService(messaging: messaging);
      final received = <String>[];
      final subscription = service.tokenRefreshes.listen(received.add);

      messaging.refreshes
        ..add('fcm-token-2')
        ..add('fcm-token-3');
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(received, ['fcm-token-2', 'fcm-token-3']);
    });

    test('foregroundMessages reduce cada mensaje a título y cuerpo', () async {
      final messages = StreamController<RemoteMessage>();
      final service = FirebasePushNotificationService(
        messaging: _FakeMessaging(),
        onMessage: messages.stream,
      );
      final received = <ForegroundPushMessage>[];
      final subscription = service.foregroundMessages.listen(received.add);

      messages
        ..add(
          const RemoteMessage(
            notification: RemoteNotification(
              title: 'Turno suspendido',
              body: 'Se suspendió el turno del 20/10/2026.',
            ),
          ),
        )
        ..add(const RemoteMessage());
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await messages.close();

      expect(received.map((m) => m.title), ['Turno suspendido', '']);
      expect(received.map((m) => m.body), [
        'Se suspendió el turno del 20/10/2026.',
        '',
      ]);
    });
  });
}
