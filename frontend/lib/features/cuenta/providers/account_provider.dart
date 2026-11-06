import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import 'account_repository_provider.dart';

/// La cuenta de quien está logueado. `autoDispose`: al salir de "Mi cuenta"
/// no queda una cuenta vieja. Sin reintento automático (`retry` en `null`):
/// la pantalla avisa y ofrece "Reintentar".
final accountProvider = FutureProvider.autoDispose<Account>((ref) async {
  final repository = await ref.watch(accountRepositoryProvider.future);
  return repository.get();
}, retry: (_, _) => null);
