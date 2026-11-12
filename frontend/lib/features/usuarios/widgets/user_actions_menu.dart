import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_role.dart';
import '../../cuenta/models/account.dart';
import '../../cuenta/providers/account_provider.dart';
import '../models/user_account.dart';
import 'user_status_dialog.dart';

/// Si el administrador de la sesión puede actuar sobre la cuenta [row]. Es el
/// único lugar donde se decide, y lo usan la tabla y la tarjeta.
///
/// - Una cuenta de socio no se inactiva desde acá (el contrato la rechaza).
/// - El administrador no se inactiva a sí mismo.
///
/// La fila propia se reconoce por CI y rol, no por id: la sesión no guarda el
/// id de la cuenta y `GET /api/cuentas/me` tampoco lo devuelve. Una persona
/// con dos cuentas las tiene con distinto rol, así que CI más rol es único. Si
/// el backend suma el id a `/api/cuentas/me`, conviene pasar a comparar por id.
///
/// Mientras la cuenta de la sesión carga o falla no se sabe cuál es la fila
/// propia: por prudencia no se ofrece el menú en ninguna fila de
/// administrador.
bool canManageAccount(UserAccount row, AsyncValue<Account> session) {
  if (row.role == UserRole.socio) return false;
  final own = session.value;
  if (own == null) return row.role != UserRole.administrador;
  return !(own.ci == row.ci && own.role == row.role);
}

/// Una acción del menú de una cuenta. Hoy hay una sola (inactivar o
/// reactivar); otras tarjetas (por ejemplo "Corregir datos") suman la suya a
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

List<_UserAction> _actionsFor(UserAccount account) {
  final active = account.status == AccountStatus.active;
  return [
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
    if (!canManageAccount(account, ref.watch(accountProvider))) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<_UserAction>(
      key: Key('user-actions-${account.id}'),
      tooltip: 'Acciones',
      onSelected: (action) => action.run(context),
      itemBuilder: (context) => [
        for (final action in _actionsFor(account))
          PopupMenuItem(
            key: action.key,
            value: action,
            child: Text(action.label),
          ),
      ],
    );
  }
}
