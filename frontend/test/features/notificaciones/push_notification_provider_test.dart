import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/features/notificaciones/providers/push_notification_provider.dart';
import 'package:agenda_medica/features/notificaciones/services/push_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

PushNotificationService _service({
  required bool useFakes,
  required bool androidPlatform,
}) {
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(useFakes),
      pushPlatformSupportedProvider.overrideWithValue(androidPlatform),
    ],
  );
  addTearDown(container.dispose);
  return container.read(pushNotificationServiceProvider);
}

void main() {
  test('en Android y sin fakes el servicio es el de Firebase', () {
    expect(
      _service(useFakes: false, androidPlatform: true),
      isA<FirebasePushNotificationService>(),
    );
  });

  test('con USE_FAKES el servicio no hace nada, aunque sea Android', () {
    expect(
      _service(useFakes: true, androidPlatform: true),
      isA<NoopPushNotificationService>(),
    );
  });

  test('fuera de Android (la web) el servicio no hace nada', () {
    expect(
      _service(useFakes: false, androidPlatform: false),
      isA<NoopPushNotificationService>(),
    );
  });

  group('la plataforma se detecta con defaultTargetPlatform', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Android es soportada', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pushPlatformSupportedProvider), isTrue);
    });

    test('iOS no es soportada', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(pushPlatformSupportedProvider), isFalse);
    });
  });
}
