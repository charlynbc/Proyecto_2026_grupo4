import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/push_tap.dart';
import '../providers/push_notification_provider.dart';
import '../services/push_notification_service.dart';

const String kDebugPushPath = '/debug/push';

/// Pantalla de prueba, solo con `USE_FAKES` (la ruta no existe sin él): simula
/// el toque de una notificación push para probar a mano la navegación en
/// Chrome, donde no hay push. No es parte de la app real.
class DebugPushScreen extends ConsumerWidget {
  const DebugPushScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(pushNotificationServiceProvider);
    if (service is! SimulatedPushNotificationService) {
      return const Scaffold(
        body: Center(child: Text('Solo disponible con datos de prueba.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Simular un aviso push')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Simula que el socio toca un aviso push. Hay que haber iniciado '
              'sesión como socio.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => service.simulateTap(
                const PushTap(
                  type: 'HISTORIA_ACTUALIZADA',
                  notificationId: 15002,
                  atencionId: 12,
                ),
              ),
              child: const Text('Historia con atención 12'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => service.simulateTap(
                const PushTap(
                  type: 'HISTORIA_ACTUALIZADA',
                  notificationId: 15003,
                ),
              ),
              child: const Text('Historia sin atención'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => service.simulateTap(
                const PushTap(type: 'AGENDA', notificationId: 15001),
              ),
              child: const Text('Consulta agendada'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => service.simulateForeground(
                const ForegroundPushMessage(
                  title: 'Historia clínica actualizada',
                  body: 'Tu historia clínica fue actualizada.',
                  tap: PushTap(
                    type: 'HISTORIA_ACTUALIZADA',
                    notificationId: 15002,
                    atencionId: 12,
                  ),
                ),
              ),
              child: const Text('Aviso con la app abierta (con Ver)'),
            ),
          ],
        ),
      ),
    );
  }
}
