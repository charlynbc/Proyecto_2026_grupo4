import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/email_change_repository.dart';
import '../repositories/first_login_repository.dart';
import 'email_change_repository_provider.dart';

enum EmailChangeStatus { idle, loading, done, linkInvalid, error }

class EmailChangeState {
  const EmailChangeState({
    this.status = EmailChangeStatus.idle,
    this.errorMessage,
  });

  final EmailChangeStatus status;
  final String? errorMessage;

  bool get isLoading => status == EmailChangeStatus.loading;
}

/// La confirmación del cambio de correo con el token del enlace. Un segundo
/// envío mientras el primero está en curso no hace otra llamada.
class EmailChangeController extends Notifier<EmailChangeState> {
  @override
  EmailChangeState build() => const EmailChangeState();

  Future<void> confirm({required String token}) async {
    // Se marca antes del primer await: un segundo toque no hace otro pedido.
    if (state.isLoading) return;
    state = const EmailChangeState(status: EmailChangeStatus.loading);
    try {
      final repository = await ref.read(emailChangeRepositoryProvider.future);
      await repository.confirm(token: token);
      state = const EmailChangeState(status: EmailChangeStatus.done);
    } on InvalidEmailChangeLinkException catch (e) {
      state = EmailChangeState(
        status: EmailChangeStatus.linkInvalid,
        errorMessage: e.message,
      );
    } catch (e) {
      state = EmailChangeState(
        status: EmailChangeStatus.error,
        errorMessage: authMessageOf(e),
      );
    }
  }
}

final emailChangeControllerProvider =
    NotifierProvider.autoDispose<EmailChangeController, EmailChangeState>(
      EmailChangeController.new,
    );
