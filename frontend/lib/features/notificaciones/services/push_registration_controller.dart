import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../repositories/device_repository.dart';
import 'push_notification_service.dart';

/// Mantiene registrado en el servidor el token push del dispositivo mientras
/// hay un socio con la sesión abierta (RNF-23, contrato filas 33 y 73).
///
/// - [start]: al iniciar sesión, pide el token y lo registra; si Firebase lo
///   renueva, lo registra de nuevo.
/// - [deactivate]: antes de cerrar sesión, da de baja el último token. Con un
///   timeout corto y sin propagar errores: cerrar sesión nunca depende de él.
/// - [stop]: deja de seguir las renovaciones (sin llamar a la API); para cuando
///   la sesión termina por otro camino.
///
/// Nunca propaga un error: un push que falla no puede romper la sesión.
class PushRegistrationController {
  PushRegistrationController({
    required this._service,
    required this._devices,
    this._deactivateTimeout = const Duration(seconds: 3),
  });

  final PushNotificationService _service;
  final Future<DeviceRepository> Function() _devices;
  final Duration _deactivateTimeout;

  String? _token;
  StreamSubscription<String>? _refreshes;

  /// Cambia con cada [start] y [stop]: un registro que quedó esperando de una
  /// corrida anterior se descarta en vez de registrar con una sesión ajena.
  int _run = 0;

  Future<void> start() async {
    final run = ++_run;
    await _cancelRefreshes();
    final token = await _service.requestToken();
    if (token == null || run != _run) return;
    _refreshes = _service.tokenRefreshes.listen(
      (newToken) => unawaited(_register(newToken, run)),
    );
    await _register(token, run);
  }

  Future<void> deactivate() async {
    final token = _token;
    stop();
    if (token == null) return;
    try {
      await (() async {
        final devices = await _devices();
        await devices.deactivate(token);
      })().timeout(_deactivateTimeout);
    } catch (e) {
      debugPrint('No se pudo dar de baja el dispositivo push: $e');
    }
  }

  void stop() {
    _run++;
    _token = null;
    final refreshes = _refreshes;
    _refreshes = null;
    unawaited(refreshes?.cancel());
  }

  Future<void> _register(String token, int run) async {
    if (run != _run) return;
    _token = token;
    try {
      final devices = await _devices();
      if (run != _run) return;
      await devices.register(token);
    } catch (e) {
      debugPrint('No se pudo registrar el dispositivo push: $e');
    }
  }

  Future<void> _cancelRefreshes() async {
    final refreshes = _refreshes;
    _refreshes = null;
    await refreshes?.cancel();
  }
}
