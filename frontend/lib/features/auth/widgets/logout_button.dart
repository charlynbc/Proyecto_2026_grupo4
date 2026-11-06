import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../cuenta/screens/account_routes.dart';
import '../providers/auth_repository_provider.dart';
import '../repositories/auth_repository.dart';

/// Íconos de la cuenta reusados en el AppBar de cada sección principal:
/// "Mi cuenta", que apila `/cuenta` sobre la pantalla actual, y cerrar
/// sesión, que pide confirmación antes de cerrarla.
///
/// Conserva el nombre `LogoutButton` aunque ahora trae los dos íconos: así
/// no se tocan las 13 pantallas que lo usan como `actions: [LogoutButton()]`.
class LogoutButton extends ConsumerStatefulWidget {
  const LogoutButton({super.key});

  @override
  ConsumerState<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends ConsumerState<LogoutButton> {
  bool _loggingOut = false;

  Future<void> _confirmAndLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Confirmás que querés cerrar la sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loggingOut = true);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      await repository.logout();
    } on AuthException {
      // La sesión local ya se limpió aunque el POST al backend haya
      // fallado, así que igual se vuelve a /login; no hace falta mostrar
      // nada más acá.
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('open-account'),
          // `push` y no `go`: la flecha de "Mi cuenta" vuelve a esta pantalla.
          onPressed: () => context.push(kAccountPath),
          tooltip: 'Mi cuenta',
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          onPressed: _loggingOut ? null : _confirmAndLogout,
          tooltip: 'Cerrar sesión',
          icon: _loggingOut
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
        ),
      ],
    );
  }
}
