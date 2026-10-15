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

/// `autoDispose`: al cambiar de acceso o salir de la pantalla se descarta el
/// error del intento anterior.
final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );
