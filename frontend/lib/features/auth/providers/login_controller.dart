import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_type.dart';
import '../repositories/auth_repository.dart';
import 'auth_repository_provider.dart';

enum LoginStatus { idle, loading, error }

class LoginState {
  const LoginState({this.status = LoginStatus.idle, this.errorMessage});

  final LoginStatus status;
  final String? errorMessage;

  bool get isLoading => status == LoginStatus.loading;
}

/// Maneja el estado de la request de login (idle/loading/error). La
/// validación de formato de los campos vive aparte, en los validators del
/// Form (ver LoginForm), no acá.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  /// Descarta el error del intento anterior. No toca un ingreso en curso ni
  /// un estado sin error.
  void clearError() {
    if (state.status == LoginStatus.error) state = const LoginState();
  }

  Future<void> submit({
    required String ci,
    required String password,
    required AccessType access,
  }) async {
    state = const LoginState(status: LoginStatus.loading);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      await repository.login(ci: ci, password: password, access: access);
      state = const LoginState(status: LoginStatus.idle);
      // La navegación a la home del rol la maneja el redirect de GoRouter
      // (ver app_router.dart): setAuthenticated() ya cambió el estado de
      // sesión, no hace falta navegar a mano acá.
    } on InvalidCredentialsException catch (e) {
      state = LoginState(status: LoginStatus.error, errorMessage: e.message);
    } on AuthException catch (e) {
      state = LoginState(status: LoginStatus.error, errorMessage: e.message);
    }
  }
}

/// `autoDispose`: al salir de la pantalla se descarta el estado. Al cambiar
/// de acceso no alcanza: el formulario nuevo se suscribe en el mismo frame en
/// que se desmonta el viejo, así que el provider sigue vivo; por eso
/// `LoginForm` llama a [LoginController.clearError] al montarse.
final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );
