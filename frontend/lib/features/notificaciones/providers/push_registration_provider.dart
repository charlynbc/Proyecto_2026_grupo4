import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/push_registration_controller.dart';
import 'device_repository_provider.dart';
import 'push_notification_provider.dart';

/// Un solo controlador para toda la app: el de `main.dart` lo arranca al
/// iniciar sesión un socio y `LogoutButton` lo usa para dar de baja el token.
final pushRegistrationControllerProvider = Provider<PushRegistrationController>(
  (ref) {
    final controller = PushRegistrationController(
      service: ref.watch(pushNotificationServiceProvider),
      devices: () => ref.read(deviceRepositoryProvider.future),
    );
    ref.onDispose(controller.stop);
    return controller;
  },
);
