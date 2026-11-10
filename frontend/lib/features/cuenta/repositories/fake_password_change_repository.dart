import '../../auth/repositories/first_login_repository.dart';
import 'password_change_repository.dart';

/// Guarda la clave cambiada en memoria. El login falso conserva su clave de
/// prueba y no consulta este repositorio.
class FakePasswordChangeRepository implements PasswordChangeRepository {
  FakePasswordChangeRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;
  String _currentPassword = 'prueba1234';

  @override
  Future<void> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future<void>.delayed(latency);
    if (currentPassword != _currentPassword) {
      throw const PasswordChangeException(
        PasswordChangeFailure.wrongCurrentPassword,
        'La contraseña actual no es correcta.',
      );
    }
    if (newPassword.length < kMinPasswordLength) {
      throw const PasswordChangeException(
        PasswordChangeFailure.validation,
        'La contraseña tiene que tener al menos 8 caracteres.',
      );
    }
    _currentPassword = newPassword;
  }
}
