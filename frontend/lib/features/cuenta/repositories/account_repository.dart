import '../../../core/network/api_exception.dart';
import '../models/account.dart';
import '../models/account_changes.dart';

class AccountValidationException extends ApiException {
  const AccountValidationException(super.message);

  const AccountValidationException.empty()
    : super('No hay ningún dato para actualizar');
}

/// Los datos de la cuenta de quien está logueado (RF-06). La identidad sale
/// de la sesión: el cliente nunca manda un id.
abstract class AccountRepository {
  Future<Account> get();
  Future<Account> update(AccountChanges changes);
}
