import 'dart:async';

import 'package:agenda_medica/features/notificaciones/models/push_tap.dart';
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
  int deleteTokenCalls = 0;

  /// Si no es `null`, `deleteToken` falla con esto.
  Object? deleteTokenError;

  /// Si no es `null`, `deleteToken` queda esperando a que se complete.
  Completer<void>? deleteTokenHang;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    if (deleteTokenError != null) throw deleteTokenError!;
    if (deleteTokenHang != null) await deleteTokenHang!.future;
  }

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

    test('no hay toque inicial ni toques en segundo plano', () async {
      expect(await service.getInitialTap(), isNull);
      expect(await service.taps.isEmpty, isTrue);
    });

    test('deleteToken completa sin error y sin tocar Firebase', () async {
      await expectLater(service.deleteToken(), completes);
    });
  });

  group('deleteToken sin Firebase', () {
    test('SimulatedPushNotificationService completa sin error', () async {
      final service = SimulatedPushNotificationService();

      await expectLater(service.deleteToken(), completes);
    });
  });

  group('FirebasePushNotificationService.deleteToken', () {
    test('llama una vez a deleteToken del SDK', () async {
      final messaging = _FakeMessaging();
      final service = FirebasePushNotificationService(messaging: messaging);

      await service.deleteToken();

      expect(messaging.deleteTokenCalls, 1);
    });

    test('si el SDK falla no propaga el error', () async {
      final messaging = _FakeMessaging()
        ..deleteTokenError = StateError('sin red');
      final service = FirebasePushNotificationService(messaging: messaging);

      await expectLater(service.deleteToken(), completes);
      expect(messaging.deleteTokenCalls, 1);
    });

    test('si el SDK no responde, termina a los 3 segundos', () {
      fakeAsync((async) {
        final messaging = _FakeMessaging()..deleteTokenHang = Completer<void>();
        final service = FirebasePushNotificationService(messaging: messaging);
        var finished = false;

        unawaited(service.deleteToken().then((_) => finished = true));
        async.elapse(const Duration(milliseconds: 2999));
        expect(finished, isFalse);

        async.elapse(const Duration(milliseconds: 1));
        async.flushMicrotasks();
        expect(finished, isTrue);
        expect(messaging.deleteTokenCalls, 1);
      });
    });
  });

  group('SimulatedPushNotificationService (USE_FAKES)', () {
    test('simulateTap emite el toque en taps', () async {
      final service = SimulatedPushNotificationService();
      final received = <PushTap>[];
      final subscription = service.taps.listen(received.add);

      service.simulateTap(
        const PushTap(
          type: 'HISTORIA_ACTUALIZADA',
          notificationId: 15002,
          atencionId: 4100,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(received, [
        const PushTap(
          type: 'HISTORIA_ACTUALIZADA',
          notificationId: 15002,
          atencionId: 4100,
        ),
      ]);
    });

    test('un toque inicial se entrega una sola vez', () async {
      final service = SimulatedPushNotificationService();
      service.queueInitialTap(const PushTap(type: 'AGENDA'));

      expect(await service.getInitialTap(), const PushTap(type: 'AGENDA'));
      expect(await service.getInitialTap(), isNull);
    });

    test('simulateForeground emite el mensaje en primer plano', () async {
      final service = SimulatedPushNotificationService();
      final received = <ForegroundPushMessage>[];
      final subscription = service.foregroundMessages.listen(received.add);

      service.simulateForeground(
        const ForegroundPushMessage(title: 'Titulo', body: 'Cuerpo'),
      );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(received.single.title, 'Titulo');
      expect(received.single.body, 'Cuerpo');
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

    test('foregroundMessages lleva el destino que dicen los data', () async {
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
            notification: RemoteNotification(title: 'Historia', body: 'x'),
            data: {
              'tipo': 'HISTORIA_ACTUALIZADA',
              'notificacionId': '15002',
              'atencionId': '4100',
            },
          ),
        )
        ..add(const RemoteMessage());
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await messages.close();

      expect(
        received[0].tap,
        const PushTap(
          type: 'HISTORIA_ACTUALIZADA',
          notificationId: 15002,
          atencionId: 4100,
        ),
      );
      expect(received[1].tap, const PushTap(type: ''));
    });

    test(
      'getInitialTap convierte el mensaje con el que se abrió la app',
      () async {
        final service = FirebasePushNotificationService(
          messaging: _FakeMessaging(),
          initialMessage: () async => const RemoteMessage(
            data: {
              'tipo': 'HISTORIA_ACTUALIZADA',
              'notificacionId': '15002',
              'atencionId': '4100',
            },
          ),
        );

        expect(
          await service.getInitialTap(),
          const PushTap(
            type: 'HISTORIA_ACTUALIZADA',
            notificationId: 15002,
            atencionId: 4100,
          ),
        );
      },
    );

    test(
      'getInitialTap devuelve null si la app no se abrió con un push',
      () async {
        final service = FirebasePushNotificationService(
          messaging: _FakeMessaging(),
          initialMessage: () async => null,
        );

        expect(await service.getInitialTap(), isNull);
      },
    );

    test('si getInitialMessage falla, getInitialTap devuelve null', () async {
      final service = FirebasePushNotificationService(
        messaging: _FakeMessaging(),
        initialMessage: () async => throw StateError('sin Firebase'),
      );

      expect(await service.getInitialTap(), isNull);
    });

    test('taps entrega cada mensaje abierto desde segundo plano', () async {
      final opened = StreamController<RemoteMessage>();
      final service = FirebasePushNotificationService(
        messaging: _FakeMessaging(),
        onMessageOpenedApp: opened.stream,
      );
      final received = <PushTap>[];
      final subscription = service.taps.listen(received.add);

      opened
        ..add(
          const RemoteMessage(data: {'tipo': 'AGENDA', 'notificacionId': '9'}),
        )
        ..add(
          const RemoteMessage(
            data: {
              'tipo': 'HISTORIA_ACTUALIZADA',
              'notificacionId': '10',
              'atencionId': 'abc',
            },
          ),
        );
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await opened.close();

      expect(received, [
        const PushTap(type: 'AGENDA', notificationId: 9),
        const PushTap(type: 'HISTORIA_ACTUALIZADA', notificationId: 10),
      ]);
    });
  });
}
