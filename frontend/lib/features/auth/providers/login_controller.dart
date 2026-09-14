import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> submit({required String ci, required String password}) async {
    state = const LoginState(status: LoginStatus.loading);
    try {
      await ref.read(authRepositoryProvider).login(ci: ci, password: password);
      state = const LoginState(status: LoginStatus.idle);
      // TODO: cuando exista navegación post-login (sesión real), acá se
      // dispararía el redirect a /home. Por ahora el router no tiene noción
      // de sesión, así que no se navega solo.
    } on InvalidCredentialsException catch (e) {
      state = LoginState(status: LoginStatus.error, errorMessage: e.message);
    }
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);
