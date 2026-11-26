import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers/refetch_when_visible_again.dart';
import '../../auth/providers/session_provider.dart';
import '../models/account.dart';
import '../models/account_changes.dart';
import 'account_repository_provider.dart';

/// La cuenta de quien está logueado, compartida por Inicio y Mi cuenta.
/// Se renueva al cambiar la sesión, aunque Inicio siga montado en el shell, y
/// al volver a la pantalla o a la app. Durante un guardado no se pide: si
/// guarda bien, su respuesta ya es el dato al día; si falla, se pide al
/// terminar. Sin reintento automático (`retry` en `null`):
/// la pantalla avisa y ofrece "Reintentar".
final accountProvider = AsyncNotifierProvider<AccountNotifier, Account>(
  AccountNotifier.new,
  isAutoDispose: true,
  retry: (_, _) => null,
);

class AccountNotifier extends AsyncNotifier<Account> {
  Object? _saveInProgress;

  /// Lecturas que esperan a que termine un guardado que no salió bien: por un
  /// cambio de sesión (recarga) o por haber vuelto (refresco).
  bool _reloadAfterSave = false;
  bool _refreshAfterSave = false;

  @override
  Future<Account> build() async {
    _saveInProgress = null;
    _reloadAfterSave = false;
    _refreshAfterSave = false;
    ref.listen(
      sessionProvider.select((s) => (s.status, s.role, s.accessToken)),
      (previous, session) {
        final authenticated = session.$1 == SessionStatus.authenticated;
        if (_saveInProgress != null &&
            authenticated &&
            previous?.$1 == SessionStatus.authenticated &&
            previous?.$2 == session.$2) {
          // La renovación del token puede ocurrir al reintentar el PATCH.
          // Si guarda bien, su respuesta reemplaza la lectura pendiente.
          _reloadAfterSave = true;
          return;
        }
        _saveInProgress = null;
        _reloadAfterSave = false;
        _refreshAfterSave = false;
        // El router ya está cerrando la pantalla al terminar la sesión.
        // Como recarga: puede ser otra cuenta, y así las pantallas distinguen
        // este pedido del que se hace al volver.
        if (authenticated) ref.invalidateSelf(asReload: true);
      },
    );
    refetchWhenVisibleAgain(ref, () {
      // Pedir acá cortaría el guardado: queda anotado por si falla.
      if (_saveInProgress != null) {
        _refreshAfterSave = true;
        return;
      }
      ref.invalidateSelf();
    });
    final repository = await ref.watch(accountRepositoryProvider.future);
    return repository.get();
  }

  Future<Account> save(AccountChanges changes) async {
    if (_saveInProgress != null) {
      throw const ApiException('Ya hay cambios que se están guardando.');
    }
    const sessionChanged = ApiException(
      'La sesión cambió durante el guardado.',
    );
    final original = state.requireValue;
    final saveRef = ref;
    final keepAlive = saveRef.keepAlive();
    final operation = Object();
    _saveInProgress = operation;
    bool isCurrent() =>
        saveRef.mounted && identical(_saveInProgress, operation);

    try {
      // Si ya había una lectura en curso, dejala terminar antes de escribir.
      final current = await future;
      if (!isCurrent() ||
          current.ci != original.ci ||
          current.role != original.role) {
        throw sessionChanged;
      }
      final repository = await saveRef.read(accountRepositoryProvider.future);
      if (!isCurrent()) throw sessionChanged;
      final updated = await repository.update(changes);
      if (!isCurrent() ||
          updated.ci != original.ci ||
          updated.role != original.role) {
        throw sessionChanged;
      }
      state = AsyncData(updated);
      _reloadAfterSave = false;
      _refreshAfterSave = false;
      return updated;
    } finally {
      if (identical(_saveInProgress, operation)) {
        _saveInProgress = null;
        if ((_reloadAfterSave || _refreshAfterSave) && saveRef.mounted) {
          saveRef.invalidateSelf(asReload: _reloadAfterSave);
        }
        _reloadAfterSave = false;
        _refreshAfterSave = false;
      }
      keepAlive.close();
    }
  }
}
