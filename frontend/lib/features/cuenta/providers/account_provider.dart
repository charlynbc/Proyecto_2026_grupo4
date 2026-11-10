import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/session_provider.dart';
import '../models/account.dart';
import 'account_repository_provider.dart';

/// La cuenta de quien está logueado, compartida por Inicio y Mi cuenta.
/// Se renueva al cambiar la sesión, aunque Inicio siga montado en el shell.
/// Sin reintento automático (`retry` en `null`):
/// la pantalla avisa y ofrece "Reintentar".
final accountProvider = FutureProvider.autoDispose<Account>((ref) async {
  ref.listen(sessionProvider.select((s) => (s.status, s.role, s.accessToken)), (
    _,
    session,
  ) {
    // No iniciar otro GET durante el logout. Al ingresar o renovar la
    // sesión, descartar los datos de la cuenta anterior.
    if (session.$1 == SessionStatus.authenticated) ref.invalidateSelf();
  });
  final repository = await ref.watch(accountRepositoryProvider.future);
  return repository.get();
}, retry: (_, _) => null);
