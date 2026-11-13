import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/models/user_role.dart';
import '../../cuenta/models/account.dart';
import '../../cuenta/providers/account_provider.dart';
import '../models/user_account.dart';
import '../screens/user_routes.dart';
import 'user_status_dialog.dart';

/// Si el administrador de la sesión puede inactivar o reactivar la cuenta
/// [row]. Es el único lugar donde se decide, y lo usan la tabla y la tarjeta.
/// "Corregir datos" no depende de esto: se ofrece en todas las filas.
///
/// - Una cuenta de socio no se inactiva desde acá (el contrato la rechaza).
/// - El administrador no se inactiva a sí mismo.
///
/// La fila propia se reconoce por el id de la cuenta y no por la CI, porque la
/// CI puede corregirse (RF-38) y la sesión conserva la vieja hasta renovarse.
///
/// Mientras la cuenta de la sesión carga o falla no se sabe cuál es la fila
/// propia: por prudencia no se ofrece inactivar en ninguna fila de
/// administrador.
bool canManageAccount(UserAccount row, AsyncValue<Account> session) {
  if (row.role == UserRole.socio) return false;
  final own = session.value;
  if (own == null) return row.role != UserRole.administrador;
  return own.id != row.id;
}

/// Una acción del menú de una cuenta. Otras tarjetas suman la suya a
/// [_actionsFor] sin rehacer el menú.
class _UserAction {
  const _UserAction({
    required this.key,
    required this.label,
    required this.run,
  });

  final Key key;
  final String label;
  final void Function(BuildContext context) run;
}

/// "Corregir datos" va en toda cuenta, incluidos los socios y la propia;
/// inactivar o reactivar solo si [canChangeStatus].
List<_UserAction> _actionsFor(
  UserAccount account, {
  required bool canChangeStatus,
}) {
  final active = account.status == AccountStatus.active;
  return [
    _UserAction(
      key: Key('user-edit-${account.id}'),
      label: 'Corregir datos',
      run: (context) => context.go(userEditPath(account.id)),
    ),
    if (canChangeStatus)
      _UserAction(
        key: Key(
          active
              ? 'user-deactivate-${account.id}'
              : 'user-reactivate-${account.id}',
        ),
        label: active ? 'Inactivar cuenta' : 'Reactivar cuenta',
        run: (context) => showUserStatusDialog(
          context: context,
          account: account,
          deactivate: active,
        ),
      ),
  ];
}

/// El menú de acciones de una cuenta del padrón (RF-45).
class UserActionsMenu extends ConsumerWidget {
  const UserActionsMenu({super.key, required this.account});

  final UserAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canChangeStatus = canManageAccount(
      account,
      ref.watch(accountProvider),
    );
    return PopupMenuButton<_UserAction>(
      key: Key('user-actions-${account.id}'),
      tooltip: 'Acciones',
      onSelected: (action) => action.run(context),
      itemBuilder: (context) => [
        for (final action in _actionsFor(
          account,
          canChangeStatus: canChangeStatus,
        ))
          PopupMenuItem(
            key: action.key,
            value: action,
            child: Text(action.label),
          ),
      ],
    );
  }
}
