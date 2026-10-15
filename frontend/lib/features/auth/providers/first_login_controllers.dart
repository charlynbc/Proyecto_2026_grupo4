import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/access_type.dart';
import '../repositories/first_login_repository.dart';
import 'first_login_repository_provider.dart';

enum FirstLoginStatus { idle, loading, done, linkInvalid, error }

class FirstLoginState {
  const FirstLoginState({
    this.status = FirstLoginStatus.idle,
    this.errorMessage,
    this.access,
  });

  final FirstLoginStatus status;
  final String? errorMessage;

  /// Solo en la activación terminada: el acceso por el que ingresar ahora.
  final AccessType? access;

  bool get isLoading => status == FirstLoginStatus.loading;
}

/// Pedido del enlace de primer ingreso. Termina en `done` siempre que el
/// pedido llegue al servidor, exista o no la cuenta.
class FirstLoginRequestController extends Notifier<FirstLoginState> {
  @override
  FirstLoginState build() => const FirstLoginState();

  Future<void> submit({required String ci, required AccessType access}) async {
    state = const FirstLoginState(status: FirstLoginStatus.loading);
    try {
      final repository = await ref.read(firstLoginRepositoryProvider.future);
      await repository.requestLink(ci: ci, access: access);
      state = const FirstLoginState(status: FirstLoginStatus.done);
    } catch (e) {
      state = FirstLoginState(
        status: FirstLoginStatus.error,
        errorMessage: authMessageOf(e),
      );
    }
  }
}

/// Activación de la cuenta con el token del enlace.
class FirstLoginActivationController extends Notifier<FirstLoginState> {
  @override
  FirstLoginState build() => const FirstLoginState();

  Future<void> submit({
    required String token,
    required String address,
    required String phone1,
    String? phone2,
    required String password,
  }) async {
    state = const FirstLoginState(status: FirstLoginStatus.loading);
    try {
      final repository = await ref.read(firstLoginRepositoryProvider.future);
      final access = await repository.activate(
        token: token,
        address: address,
        phone1: phone1,
        phone2: phone2,
        password: password,
      );
      state = FirstLoginState(status: FirstLoginStatus.done, access: access);
    } on InvalidActivationLinkException catch (e) {
      state = FirstLoginState(
        status: FirstLoginStatus.linkInvalid,
        errorMessage: e.message,
      );
    } catch (e) {
      state = FirstLoginState(
        status: FirstLoginStatus.error,
        errorMessage: authMessageOf(e),
      );
    }
  }
}

final firstLoginRequestControllerProvider =
    NotifierProvider.autoDispose<FirstLoginRequestController, FirstLoginState>(
      FirstLoginRequestController.new,
    );

final firstLoginActivationControllerProvider =
    NotifierProvider.autoDispose<
      FirstLoginActivationController,
      FirstLoginState
    >(FirstLoginActivationController.new);
