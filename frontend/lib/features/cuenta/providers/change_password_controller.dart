import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/password_change_repository.dart';
import 'password_change_repository_provider.dart';

enum ChangePasswordStatus { idle, saving, done, error }

class ChangePasswordState {
  const ChangePasswordState({
    this.status = ChangePasswordStatus.idle,
    this.failure,
    this.message,
  });

  final ChangePasswordStatus status;
  final PasswordChangeFailure? failure;
  final String? message;
}

class ChangePasswordController extends Notifier<ChangePasswordState> {
  @override
  ChangePasswordState build() => const ChangePasswordState();

  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.status == ChangePasswordStatus.saving) return false;
    state = const ChangePasswordState(status: ChangePasswordStatus.saving);
    try {
      final repository = await ref.read(
        passwordChangeRepositoryProvider.future,
      );
      await repository.change(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = const ChangePasswordState(status: ChangePasswordStatus.done);
      return true;
    } on PasswordChangeException catch (error) {
      state = ChangePasswordState(
        status: ChangePasswordStatus.error,
        failure: error.failure,
        message: error.message,
      );
    } catch (_) {
      state = const ChangePasswordState(
        status: ChangePasswordStatus.error,
        failure: PasswordChangeFailure.other,
      );
    }
    return false;
  }

  void clearError() {
    if (state.status == ChangePasswordStatus.error) {
      state = const ChangePasswordState();
    }
  }
}

final changePasswordControllerProvider =
    NotifierProvider.autoDispose<ChangePasswordController, ChangePasswordState>(
      ChangePasswordController.new,
    );
