import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final SessionStatus status;
  final String? accessToken;
  final String? role;

  bool get isAuthenticated => status == SessionStatus.authenticated;
}

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    // Arranca en `unauthenticated`, no en `checking`: el bootstrap que
    // llama a POST /api/auth/refresh al arrancar la app (lo que llevaría a
    // `checking` mientras se espera esa respuesta) todavía no está
    // implementado, así que hoy nada saca a la app de `checking` si
    // arrancara ahí.
    return const SessionState();
  }

  void setAuthenticated({required String accessToken, required String role}) {
    state = SessionState(
      status: SessionStatus.authenticated,
      accessToken: accessToken,
      role: role,
    );
  }

  void clear() {
    state = const SessionState(status: SessionStatus.unauthenticated);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);
