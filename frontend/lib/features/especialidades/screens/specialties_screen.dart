import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/specialty.dart';
import '../providers/specialty_filters_controller.dart';
import '../providers/specialty_search_provider.dart';
import '../repositories/specialty_search_repository.dart';
import '../widgets/specialty_filter_bar.dart';

const String kSpecialtiesPath = '/admin/especialidades';
const String kNewSpecialtyPath = '/admin/especialidades/nueva';

/// Consulta de especialidades con filtros (RF-36) y acceso al alta (RF-29).
class SpecialtiesScreen extends ConsumerWidget {
  const SpecialtiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specialties = ref.watch(specialtySearchProvider);
    final filters = ref.watch(specialtyFiltersControllerProvider);
    final hasFilters = (filters.name?.trim().isNotEmpty ?? false) ||
        filters.requiresReferral != null;
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
            SpecialtyFilterBar(
              onSearch: (selected) => ref
                  .read(specialtyFiltersControllerProvider.notifier)
                  .apply(
                    name: selected.name,
                    requiresReferral: selected.requiresReferral,
                    order: selected.order,
                  ),
              onClear: () => ref
                  .read(specialtyFiltersControllerProvider.notifier)
                  .clear(),
            ),
            const SizedBox(height: 16),
            ...specialties.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (error, _) => [
                Text(
                  _errorMessage(error),
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => ref.invalidate(specialtySearchProvider),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [
                      if (hasFilters)
                        const Text(
                          'No hay especialidades que coincidan.',
                          key: Key('specialty-filter-empty'),
                        )
                      else
                        const Text('Todavía no hay especialidades registradas.'),
                    ]
                  : [for (final item in items) _SpecialtyTile(item)],
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object error) => switch (error) {
    SpecialtySearchException(failure: SpecialtySearchFailure.unauthenticated) =>
      'Tu sesión venció. Iniciá sesión nuevamente.',
    SpecialtySearchException(failure: SpecialtySearchFailure.forbidden) =>
      'Tu cuenta no tiene permiso para ver las especialidades.',
    SpecialtySearchException(failure: SpecialtySearchFailure.validation) =>
      apiMessageOf(error),
    _ => 'No pudimos cargar las especialidades. Intentá de nuevo.',
  };
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
