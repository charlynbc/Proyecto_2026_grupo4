import 'dart:async';

import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../models/push_tap.dart';
import 'push_destination.dart';
import 'push_notification_service.dart';

/// Lleva al socio a donde dice la notificación push que tocó (RNF-23).
///
/// - [start]: escucha los toques con la app en segundo plano y atiende el
///   toque con el que se abrió la app desde cerrada.
/// - [handleTap]: con un socio autenticado navega en el momento; con otro rol
///   lo ignora; sin sesión (verificándose o sin iniciar) lo deja como destino
///   pendiente, y si llegan varios queda el último.
/// - [onSessionChanged]: cuando la sesión queda autenticada consume el destino
///   pendiente: lo abre si es un socio y lo descarta si es otro rol.
///
/// No conoce el router ni los providers: se lo dan [_navigate] (abre las rutas
/// en orden: la primera con `go` y la segunda, si hay, apilada con `push`) y
/// [_refreshNotifications] (vuelve a pedir la lista de Avisos).
class PushNavigationController {
  PushNavigationController({
    required this._service,
    required this._session,
    required this._navigate,
    required this._refreshNotifications,
  });

  final PushNotificationService _service;
  final SessionState Function() _session;
  final Future<void> Function(List<String> routes) _navigate;
  final void Function() _refreshNotifications;

  StreamSubscription<PushTap>? _subscription;
  PushTap? _pending;

  Future<void> start() async {
    await _subscription?.cancel();
    _subscription = _service.taps.listen((tap) => unawaited(handleTap(tap)));
    final initial = await _service.getInitialTap();
    if (initial != null) await handleTap(initial);
  }

  void stop() {
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
  }

  Future<void> handleTap(PushTap tap) async {
    final session = _session();
    if (!session.isAuthenticated) {
      _pending = tap;
      return;
    }
    if (session.role != UserRole.socio) return;
    await _open(tap);
  }

  void onSessionChanged(SessionState session) {
    final pending = _pending;
    if (pending == null || !session.isAuthenticated) return;
    _pending = null;
    if (session.role == UserRole.socio) unawaited(_open(pending));
  }

  Future<void> _open(PushTap tap) async {
    await _navigate(destinationForPush(tap));
    _refreshNotifications();
  }
}
