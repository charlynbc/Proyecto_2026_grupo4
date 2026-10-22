import 'package:flutter/material.dart';

import '../../features/auth/widgets/logout_button.dart';
import 'centered_content.dart';

/// Una función que el backend todavía no ofrece.
class PendingFeature {
  const PendingFeature({
    required this.title,
    required this.detail,
    this.disabledAction,
  });

  final String title;
  final String detail;

  /// Texto de la acción que existirá cuando se implemente. Se muestra
  /// deshabilitada: no hay nada que ejecutar.
  final String? disabledAction;
}

/// Pantalla de una sección cuyo backend todavía no existe. A diferencia de
/// `ComingSoonScreen`, dice qué falta y por qué: no muestra listas vacías,
/// datos de ejemplo ni errores 404 que parezcan resultados reales.
class PendingFeatureScreen extends StatelessWidget {
  const PendingFeatureScreen({
    super.key,
    required this.title,
    required this.features,
  });

  final String title;
  final List<PendingFeature> features;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LogoutButton()]),
      body: CenteredContent(
        maxWidth: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                Icons.hourglass_empty_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Pendiente de implementación',
                style: textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estas funciones todavía no están disponibles en el servidor, '
              'así que acá no se muestran datos.',
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            for (final feature in features)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feature.title, style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(feature.detail),
                      if (feature.disabledAction != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: null,
                          child: Text(feature.disabledAction!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
