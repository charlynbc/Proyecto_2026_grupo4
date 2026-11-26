import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../services/push_notification_service.dart';

/// El push existe solo en Android (RNF-23). Los tests lo sobreescriben.
final pushPlatformSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// Punto único de inyección del servicio de notificaciones push. Con
/// `USE_FAKES` o fuera de Android no se toca Firebase ni se pide permiso. Con
/// `USE_FAKES` el servicio deja simular un toque de push a mano.
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  if (ref.watch(useFakesProvider)) {
    return SimulatedPushNotificationService();
  }
  if (!ref.watch(pushPlatformSupportedProvider)) {
    return const NoopPushNotificationService();
  }
  return FirebasePushNotificationService();
});
