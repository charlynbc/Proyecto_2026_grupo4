import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/clinic.dart';
import '../providers/clinics_provider.dart';

const String kClinicsPath = '/admin/consultorios';
const String kNewClinicPath = '/admin/consultorios/nuevo';

/// Catálogo de consultorios del administrador (RF-33): la lista y el acceso
/// al alta.
class ClinicsScreen extends ConsumerWidget {
  const ClinicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinics = ref.watch(clinicsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultorios'),
        actions: const [LogoutButton()],
      ),
      body: CenteredContent(
        maxWidth: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => context.go(kNewClinicPath),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo consultorio'),
              ),
            ),
            const SizedBox(height: 16),
            ...clinics.when(
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (error, _) => [
                Text(
                  'No pudimos cargar los consultorios. Intentá de nuevo.',
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => ref.invalidate(clinicsProvider),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? const [Text('Todavía no hay consultorios registrados.')]
                  : [for (final item in items) _ClinicTile(item)],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClinicTile extends StatelessWidget {
  const _ClinicTile(this.clinic);

  final Clinic clinic;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(clinic.name),
        subtitle: Text(clinic.location),
      ),
    );
  }
}
