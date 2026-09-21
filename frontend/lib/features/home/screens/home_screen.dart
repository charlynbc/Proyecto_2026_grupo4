import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_repository_provider.dart';
import '../../auth/repositories/auth_repository.dart';

/// Home provisoria: por ahora solo tiene el botón de cerrar sesión. No
/// navega de vuelta a /login a mano: logout() limpia sessionProvider en el
/// finally de ApiAuthRepository.logout (corra o no la request al backend), y
/// eso hace que el redirect de GoRouter mande solo a /login.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => context.go('/agenda'),
              child: const Text('Ir a la agenda'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loggingOut ? null : _logout,
              child: _loggingOut
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
