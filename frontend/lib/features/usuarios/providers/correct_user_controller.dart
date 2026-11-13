import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../repositories/user_correction_repository.dart';
import 'account_detail_provider.dart';
import 'user_correction_repository_provider.dart';
import 'users_page_provider.dart';

/// El estado de una corrección: el de un envío más el motivo del rechazo, para
/// que la pantalla decida bajo qué campo mostrar el mensaje.
class CorrectUserState extends SubmitState {
  const CorrectUserState({super.status, super.errorMessage, this.failure});

  /// Solo con [SubmitStatus.error].
  final UserCorrectionFailure? failure;
}

/// Corrección de los datos de una cuenta (RF-38). Al terminar bien invalida el
/// padrón y el detalle de la cuenta, sin tocar los filtros ni la página
/// elegida.
class CorrectUserController extends Notifier<CorrectUserState> {
  @override
  CorrectUserState build() => const CorrectUserState();

  /// Saca el error mostrado, por ejemplo cuando se vuelve a escribir el campo.
  void clearError() {
    if (state.status == SubmitStatus.error) state = const CorrectUserState();
  }

  Future<void> correct(int id, AccountCorrection changes) async {
    if (state.isLoading) return;
    // Si se sale de la pantalla mientras se envía, la corrección igual termina.
    final link = ref.keepAlive();
    state = const CorrectUserState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(
        userCorrectionRepositoryProvider.future,
      );
      await repository.correct(id, changes);
      ref.invalidate(usersPageProvider);
      ref.invalidate(accountDetailProvider(id));
      state = const CorrectUserState(status: SubmitStatus.done);
    } on UserCorrectionException catch (e) {
      if (e.failure == UserCorrectionFailure.notFound) {
        // La fila estaba desactualizada: la página se vuelve a pedir.
        ref.invalidate(usersPageProvider);
      }
      state = CorrectUserState(
        status: SubmitStatus.error,
        errorMessage: e.message,
        failure: e.failure,
      );
    } catch (e) {
      state = CorrectUserState(
        status: SubmitStatus.error,
        errorMessage: apiMessageOf(e),
        failure: UserCorrectionFailure.other,
      );
    } finally {
      link.close();
    }
  }
}

final correctUserControllerProvider =
    NotifierProvider.autoDispose<CorrectUserController, CorrectUserState>(
      CorrectUserController.new,
    );
