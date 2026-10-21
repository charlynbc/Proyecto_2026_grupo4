import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../models/new_user.dart';
import 'user_repository_provider.dart';
import 'users_page_provider.dart';

/// Alta de un usuario (RF-31). Al terminar bien invalida el listado.
class CreateUserController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<void> submit(NewUser user) async {
    // Si se sale de la pantalla mientras se envía, el alta igual termina.
    final link = ref.keepAlive();
    state = const SubmitState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(userRepositoryProvider.future);
      await repository.createUser(user);
      ref.invalidate(usersPageProvider);
      state = const SubmitState(status: SubmitStatus.done);
    } catch (e) {
      state = SubmitState(
        status: SubmitStatus.error,
        errorMessage: apiMessageOf(e),
      );
    } finally {
      link.close();
    }
  }
}

final createUserControllerProvider =
    NotifierProvider.autoDispose<CreateUserController, SubmitState>(
      CreateUserController.new,
    );
