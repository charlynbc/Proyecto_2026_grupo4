import '../../../core/network/api_exception.dart';

abstract class PasswordChangeRepository {
  Future<void> change({
    required String currentPassword,
    required String newPassword,
  });
}

enum PasswordChangeFailure { wrongCurrentPassword, validation, other }

class PasswordChangeException extends ApiException {
  const PasswordChangeException(this.failure, [super.message]);

  final PasswordChangeFailure failure;
}
