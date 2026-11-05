import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/email_change_controller.dart';
import '../repositories/email_change_repository.dart';
import '../widgets/auth_scaffold.dart';

/// Confirmar el cambio de correo, a la que lleva el enlace que el backend
/// manda al correo nuevo (`/cambio-correo?token=<token>`). RF-06.
///
/// No confirma sola al abrirse: el enlace es de un solo uso, y confirmar al
/// abrir lo consumiría ante una recarga de la página o un doble render. Se
/// abre con o sin sesión.
class ConfirmEmailChangeScreen extends ConsumerWidget {
  const ConfirmEmailChangeScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emailChangeControllerProvider);

    final homeButton = FilledButton(
      key: const Key('email-change-home'),
      // El router lleva al login sin sesión, o al inicio del rol con sesión.
      onPressed: () => context.go('/'),
      child: const Text('Ir al inicio'),
    );

    if (state.status == EmailChangeStatus.done) {
      return AuthScaffold(
        subtitle: 'Confirmar cambio de correo',
        children: [
          const AuthNotice(
            title: 'Correo actualizado',
            messages: [kEmailChangedMessage],
          ),
          const SizedBox(height: 16),
          homeButton,
        ],
      );
    }

    if (state.status == EmailChangeStatus.linkInvalid) {
      return AuthScaffold(
        subtitle: 'Confirmar cambio de correo',
        children: [
          AuthNotice(
            title: 'No pudimos cambiar tu correo',
            isError: true,
            messages: [state.errorMessage ?? ''],
          ),
          const SizedBox(height: 16),
          homeButton,
        ],
      );
    }

    return AuthScaffold(
      subtitle: 'Confirmar cambio de correo',
      children: [
        Text(
          'Confirmá que querés usar este correo en tu cuenta. El enlace sirve '
          'una sola vez y vale 24 horas.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('email-change-confirm'),
          onPressed: state.isLoading
              ? null
              : () => ref
                    .read(emailChangeControllerProvider.notifier)
                    .confirm(token: token),
          child: state.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar cambio de correo'),
        ),
        if (state.status == EmailChangeStatus.error) ...[
          const SizedBox(height: 12),
          AuthNotice(
            title: 'No pudimos cambiar tu correo',
            messages: [state.errorMessage ?? ''],
            isError: true,
          ),
        ],
      ],
    );
  }
}
