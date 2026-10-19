import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/specialty.dart';
import '../providers/specialties_provider.dart';

const String kSpecialtiesPath = '/admin/especialidades';
const String kNewSpecialtyPath = '/admin/especialidades/nueva';

/// Catálogo de especialidades del administrador (RF-29): la lista y el acceso
/// al alta.
class SpecialtiesScreen extends ConsumerWidget {
  const SpecialtiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specialties = ref.watch(specialtiesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Especialidades'),
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
                onPressed: () => context.go(kNewSpecialtyPath),
                icon: const Icon(Icons.add),
                label: const Text('Nueva especialidad'),
              ),
            ),
            const SizedBox(height: 16),
            ...specialties.when(
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (error, _) => [
                Text(
                  'No pudimos cargar las especialidades. Intentá de nuevo.',
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => ref.invalidate(specialtiesProvider),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? const [Text('Todavía no hay especialidades registradas.')]
                  : [for (final item in items) _SpecialtyTile(item)],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyTile extends StatelessWidget {
  const _SpecialtyTile(this.specialty);

  final Specialty specialty;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(specialty.name),
        trailing: Text(specialty.requiresReferral ? 'Requiere pase' : 'Libre'),
      ),
    );
  }
}
