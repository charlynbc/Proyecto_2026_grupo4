import 'dart:async';

import 'package:agenda_medica/features/notificaciones/models/device_registration.dart';
import 'package:agenda_medica/features/notificaciones/models/push_tap.dart';
import 'package:agenda_medica/features/notificaciones/repositories/device_repository.dart';
import 'package:agenda_medica/features/notificaciones/services/push_notification_service.dart';

/// Un servicio de push que no toca Firebase: entrega el token que se le
/// indica y deja emitir renovaciones y mensajes a mano.
class FakePushService implements PushNotificationService {
  FakePushService({this.token = 'fcm-token-1'});

  String? token;
  Completer<String?>? pendingToken;
  int tokenRequests = 0;
  final StreamController<String> refreshes =
      StreamController<String>.broadcast();
  final StreamController<ForegroundPushMessage> messages =
      StreamController<ForegroundPushMessage>.broadcast();
  final StreamController<PushTap> tapEvents =
      StreamController<PushTap>.broadcast();

  /// El toque con el que "se abrió la app" (se entrega una sola vez).
  PushTap? initialTap;

  @override
  Future<String?> requestToken() {
    tokenRequests++;
    return pendingToken?.future ?? Future.value(token);
  }

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Stream<ForegroundPushMessage> get foregroundMessages => messages.stream;

  @override
  Future<PushTap?> getInitialTap() async {
    final tap = initialTap;
    initialTap = null;
    return tap;
  }

  @override
  Stream<PushTap> get taps => tapEvents.stream;
}

/// Un repositorio que anota cada llamada, en orden, en [events] (que se puede
/// compartir con otros dobles para comprobar el orden entre ellos).
class RecordingDeviceRepository implements DeviceRepository {
  RecordingDeviceRepository({List<String>? events, this.error, this.hang})
    : events = events ?? [];

  final List<String> events;

  /// Si no es `null`, cada llamada anota el evento y después falla con esto.
  final Object? error;

  /// Si no es `null`, la baja anota el evento y queda esperando (el registro
  /// no se cuelga).
  final Completer<void>? hang;

  @override
  Future<DeviceRegistration> register(String token) async {
    events.add('register:$token');
    if (error != null) throw error!;
    return DeviceRegistration(
      id: 1,
      enabled: true,
      registeredAt: DateTime.utc(2026, 11, 14, 15),
      created: true,
    );
  }

  @override
  Future<void> deactivate(String token) async {
    events.add('deactivate:$token');
    if (error != null) throw error!;
    if (hang != null) await hang!.future;
  }
}
