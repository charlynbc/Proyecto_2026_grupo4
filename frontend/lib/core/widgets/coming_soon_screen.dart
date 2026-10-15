import 'package:flutter/material.dart';

import '../../features/auth/widgets/logout_button.dart';
import 'centered_content.dart';

/// Pantalla común de las secciones que todavía no existen.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LogoutButton()]),
      body: CenteredContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'Próximamente',
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Esta sección todavía no está disponible. Mientras tanto podés '
              'usar las otras secciones del menú.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
