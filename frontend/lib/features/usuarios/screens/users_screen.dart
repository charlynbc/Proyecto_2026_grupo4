import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../widgets/users_filter_bar.dart';
import '../widgets/users_results.dart';
import 'user_routes.dart';

/// Padrón de usuarios del administrador (RF-35, CU 3.5.4) y acceso al alta.
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: const [LogoutButton()],
      ),
      body: CenteredContent(
        maxWidth: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => context.go(kNewUserPath),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Alta de usuario'),
              ),
            ),
            const SizedBox(height: 16),
            const UsersFilterBar(),
            const SizedBox(height: 8),
            Text(
              'Una fila por cuenta: una persona con varias cuentas aparece '
              'una vez por cada una.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const UsersResults(),
          ],
        ),
      ),
    );
  }
}
