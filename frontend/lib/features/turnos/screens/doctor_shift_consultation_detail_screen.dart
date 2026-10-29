import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder funcional para el detalle de una consulta activa.
class DoctorShiftConsultationDetailScreen extends StatelessWidget {
  const DoctorShiftConsultationDetailScreen({
    super.key,
    required this.consultationId,
  });

  final int consultationId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de consulta'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consulta activa',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Identificador: #$consultationId',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Esta pantalla todavía es un placeholder funcional: aquí se ' 
                        'mostrarán los datos completos de la consulta, el paciente, '
                        'la atención y el historial cuando se conecte el detalle real.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Volver'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
