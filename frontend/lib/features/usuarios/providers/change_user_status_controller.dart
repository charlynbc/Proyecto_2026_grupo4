import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../repositories/user_status_repository.dart';
import 'user_status_repository_provider.dart';
import 'users_page_provider.dart';

/// El estado de un cambio de estado de cuenta: el de un envío más el motivo
/// del rechazo, para que el diálogo decida qué mostrar.
class ChangeUserStatusState extends SubmitState {
  const ChangeUserStatusState({super.status, super.errorMessage, this.failure});

  /// Solo con [SubmitStatus.error] de un cambio rechazado por el servidor.
  final UserStatusFailure? failure;
}

/// Inactivar o reactivar una cuenta (RF-45). Al terminar bien invalida la
/// página del padrón, sin tocar los filtros ni la página elegida.
class ChangeUserStatusController extends Notifier<ChangeUserStatusState> {
  @override
  ChangeUserStatusState build() => const ChangeUserStatusState();

  Future<void> submit(int id, {required bool deactivate}) async {
    if (state.isLoading) return;
    // Si se sale de la pantalla mientras se envía, el cambio igual termina.
    final link = ref.keepAlive();
    state = const ChangeUserStatusState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(userStatusRepositoryProvider.future);
      if (deactivate) {
        await repository.deactivate(id);
      } else {
        await repository.reactivate(id);
      }
      ref.invalidate(usersPageProvider);
      state = const ChangeUserStatusState(status: SubmitStatus.done);
    } on UserStatusException catch (e) {
      if (isStaleRowFailure(e.failure)) {
        // La fila estaba desactualizada: la página se vuelve a pedir.
        ref.invalidate(usersPageProvider);
      }
      state = ChangeUserStatusState(
        status: SubmitStatus.error,
        errorMessage: e.message,
        failure: e.failure,
      );
    } catch (e) {
      state = ChangeUserStatusState(
        status: SubmitStatus.error,
        errorMessage: apiMessageOf(e),
      );
    } finally {
      link.close();
    }
  }
}

/// Los rechazos que significan "lo que veías ya no es así": el diálogo se
/// cierra con el aviso en un SnackBar y la página se vuelve a pedir.
bool isStaleRowFailure(UserStatusFailure? failure) =>
    failure == UserStatusFailure.notFound ||
    failure == UserStatusFailure.alreadyInactive ||
    failure == UserStatusFailure.alreadyActive;

final changeUserStatusControllerProvider =
    NotifierProvider.autoDispose<
      ChangeUserStatusController,
      ChangeUserStatusState
    >(ChangeUserStatusController.new);
