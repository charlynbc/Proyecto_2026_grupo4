import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../models/user_account.dart';
import '../providers/change_user_status_controller.dart';
import '../repositories/user_status_repository.dart';

/// Pide confirmar la inactivación o la reactivación de [account] (RF-45).
Future<void> showUserStatusDialog({
  required BuildContext context,
  required UserAccount account,
  required bool deactivate,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => UserStatusDialog(account: account, deactivate: deactivate),
);

/// Lo que se agrega debajo del mensaje del servidor, según el rechazo.
String? _helpFor(UserStatusFailure? failure) => switch (failure) {
  UserStatusFailure.doctorHasShifts ||
  UserStatusFailure.doctorHasAppointments =>
    'Primero hay que suspender las fechas de turnos de este médico y cancelar '
        'sus consultas agendadas.',
  UserStatusFailure.duplicateStaff =>
    'Ya hay otra cuenta de empleado habilitada con esta CI.',
  _ => null,
};

class UserStatusDialog extends ConsumerWidget {
  const UserStatusDialog({
    super.key,
    required this.account,
    required this.deactivate,
  });

  final UserAccount account;
  final bool deactivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(changeUserStatusControllerProvider, (_, state) {
      final messenger = ScaffoldMessenger.of(context);
      if (state.status == SubmitStatus.done) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              deactivate ? 'Cuenta inactivada.' : 'Cuenta reactivada.',
            ),
          ),
        );
      } else if (state.status == SubmitStatus.error &&
          isStaleRowFailure(state.failure)) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(state.errorMessage ?? '')),
        );
      }
    });
    final state = ref.watch(changeUserStatusControllerProvider);
    final sending = state.isLoading;
    final failed = state.status == SubmitStatus.error;
    final help = failed ? _helpFor(state.failure) : null;
    final name = '${account.firstName} ${account.lastName}';
    final body = deactivate
        ? '$name (${account.ci}) no va a poder ingresar y sus sesiones '
              'abiertas se cierran. Sus datos y su historial se conservan. '
              'Podés reactivarla cuando quieras.'
        : '$name (${account.ci}) va a poder ingresar de nuevo. Las fechas de '
              'turnos suspendidas siguen suspendidas.';
    return PopScope(
      canPop: !sending,
      child: AlertDialog(
        key: const Key('user-status-dialog'),
        scrollable: true,
        title: Text(
          deactivate ? '¿Inactivar esta cuenta?' : '¿Reactivar esta cuenta?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            if (failed) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? '',
                key: const Key('user-status-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (help != null) ...[
                const SizedBox(height: 8),
                Text(help, key: const Key('user-status-help')),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('user-status-cancel'),
            onPressed: sending ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('user-status-confirm'),
            onPressed: sending
                ? null
                : () => ref
                      .read(changeUserStatusControllerProvider.notifier)
                      .submit(account.id, deactivate: deactivate),
            child: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(deactivate ? 'Inactivar' : 'Reactivar'),
          ),
        ],
      ),
    );
  }
}
