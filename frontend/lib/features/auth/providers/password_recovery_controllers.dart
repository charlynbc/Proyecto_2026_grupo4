import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_type.dart';
import '../repositories/first_login_repository.dart';
import '../repositories/password_recovery_repository.dart';
import 'password_recovery_repository_provider.dart';

enum PasswordRecoveryStatus { idle, loading, done, linkInvalid, error }

class PasswordRecoveryState {
  const PasswordRecoveryState({
    this.status = PasswordRecoveryStatus.idle,
    this.errorMessage,
  });

  final PasswordRecoveryStatus status;
  final String? errorMessage;

  bool get isLoading => status == PasswordRecoveryStatus.loading;
}

/// Pedido del enlace de recuperación. Termina en `done` siempre que el pedido
/// llegue al servidor, exista o no la cuenta.
class PasswordRecoveryRequestController
    extends Notifier<PasswordRecoveryState> {
  @override
  PasswordRecoveryState build() => const PasswordRecoveryState();

  Future<void> submit({required String ci, required AccessType access}) async {
    if (state.isLoading) return;
    state = const PasswordRecoveryState(status: PasswordRecoveryStatus.loading);
    try {
      final repository = await ref.read(
        passwordRecoveryRepositoryProvider.future,
      );
      await repository.requestLink(ci: ci, access: access);
      state = const PasswordRecoveryState(status: PasswordRecoveryStatus.done);
    } catch (e) {
      state = PasswordRecoveryState(
        status: PasswordRecoveryStatus.error,
        errorMessage: authMessageOf(e),
      );
    }
  }
}

/// La contraseña nueva, con el token del enlace. Un segundo envío mientras
/// el primero está en curso no hace otra llamada.
class PasswordRecoveryCompleteController
    extends Notifier<PasswordRecoveryState> {
  @override
  PasswordRecoveryState build() => const PasswordRecoveryState();

  Future<void> submit({required String token, required String password}) async {
    // Se marca antes del primer await: un segundo toque no hace otro pedido.
    if (state.isLoading) return;
    state = const PasswordRecoveryState(status: PasswordRecoveryStatus.loading);
    try {
      final repository = await ref.read(
        passwordRecoveryRepositoryProvider.future,
      );
      await repository.complete(token: token, password: password);
      state = const PasswordRecoveryState(status: PasswordRecoveryStatus.done);
    } on InvalidRecoveryLinkException catch (e) {
      state = PasswordRecoveryState(
        status: PasswordRecoveryStatus.linkInvalid,
        errorMessage: e.message,
      );
    } catch (e) {
      state = PasswordRecoveryState(
        status: PasswordRecoveryStatus.error,
        errorMessage: authMessageOf(e),
      );
    }
  }
}

final passwordRecoveryRequestControllerProvider =
    NotifierProvider.autoDispose<
      PasswordRecoveryRequestController,
      PasswordRecoveryState
    >(PasswordRecoveryRequestController.new);

final passwordRecoveryCompleteControllerProvider =
    NotifierProvider.autoDispose<
      PasswordRecoveryCompleteController,
      PasswordRecoveryState
    >(PasswordRecoveryCompleteController.new);
