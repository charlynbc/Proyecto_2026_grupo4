import '../models/account.dart';

/// Los datos de la cuenta de quien está logueado (RF-06). La identidad sale
/// de la sesión: el cliente nunca manda un id.
abstract class AccountRepository {
  Future<Account> get();
}
