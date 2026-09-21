import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository_provider.dart';

enum SessionStatus { checking, authenticated, unauthenticated }

/// Estado de sesión en memoria. El access token vive únicamente acá: nunca
/// se persiste (ni `localStorage`, ni `flutter_secure_storage`, ni
/// `SharedPreferences`), así que se pierde a propósito al recargar la
/// página.
class SessionState {
  const SessionState({
    this.status = SessionStatus.unauthenticated,
    this.accessToken,
    this.role,
    this.expired = false,
  });

  final SessionStatus status;
  final String? accessToken;
  final String? role;

  /// True cuando se llegó a `unauthenticated` porque una sesión que estaba
  /// activa dejó de serlo (el refresh del interceptor de auth devolvió 401
  /// en medio del uso de la app), y no por un logout voluntario ni porque el
  /// bootstrap inicial no encontró sesión previa. La consume `LoginScreen`
  /// vía [SessionNotifier.consumeExpired] para mostrar un aviso distinto.
  final bool expired;

  bool get isAuthenticated => status == SessionStatus.authenticated;
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Arranca en `checking`: al iniciar no sabemos todavía si la cookie
    // HttpOnly de refresh (invisible para Dart) sigue siendo válida. Se
    // difiere el bootstrap con un microtask para que corra después de que
    // build() termine de devolver este estado inicial: recién ahí el
    // notifier está completamente inicializado y se puede leer
    // sessionProvider.notifier desde otros providers (como
    // authRepositoryProvider) sin depender del orden de construcción.
    unawaited(Future.microtask(_bootstrap));
    return const SessionState(status: SessionStatus.checking);
  }

  Future<void> _bootstrap() async {
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      if (!ref.mounted) return;
      await repository.refresh();
      // Si funciona, ApiAuthRepository ya llamó a setAuthenticated() por su
      // cuenta: acá no hay nada más que hacer.
    } catch (_) {
      // Caso normal la primera vez que alguien abre la app: todavía no hay
      // sesión previa y el backend devuelve 401. No es un error, así que no
      // se loguea y no se marca como `expired` (eso queda solo para
      // AuthInterceptor, cuando una sesión que sí estaba activa se cae).
      if (!ref.mounted) return;
      clear();
    }
  }

  void setAuthenticated({required String accessToken, required String role}) {
    state = SessionState(
      status: SessionStatus.authenticated,
      accessToken: accessToken,
      role: role,
    );
  }

  /// Pasa el estado a `unauthenticated`. [expired] distingue una sesión que
  /// caducó en medio del uso de la app de un logout voluntario o del
  /// bootstrap inicial sin sesión previa (ninguno de esos dos es un error).
  void clear({bool expired = false}) {
    state = SessionState(status: SessionStatus.unauthenticated, expired: expired);
  }

  /// Lee si la sesión terminó por expiración y resetea el flag a `false` en
  /// la misma llamada, para que no sobreviva a la próxima navegación ni a
  /// un F5. Pensado para llamarse una sola vez, cuando `/login` se muestra.
  bool consumeExpired() {
    final wasExpired = state.expired;
    if (wasExpired) {
      state = SessionState(
        status: state.status,
        accessToken: state.accessToken,
        role: state.role,
      );
    }
    return wasExpired;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
