import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/clinic.dart';
import '../providers/clinic_filters_controller.dart';
import '../providers/clinic_search_provider.dart';
import '../repositories/clinic_search_repository.dart';
import '../widgets/clinic_filter_bar.dart';

const String kClinicsPath = '/admin/consultorios';
const String kNewClinicPath = '/admin/consultorios/nuevo';
const String kImportClinicsPath = '/admin/consultorios/importar';

/// Consulta de consultorios con filtros (RF-37) y acceso al alta (RF-33).
class ClinicsScreen extends ConsumerWidget {
  const ClinicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinics = ref.watch(clinicListProvider);
    final filters = ref.watch(clinicFiltersControllerProvider);
    final hasFilters =
        (filters.name?.trim().isNotEmpty ?? false) ||
        (filters.location?.trim().isNotEmpty ?? false);
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
            // En un Wrap alineado a la derecha: a 320 px los botones pasan a
            // dos renglones en vez de desbordar.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('clinics-import-button'),
                  onPressed: () => context.go(kImportClinicsPath),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Cargar desde CSV'),
                ),
                FilledButton.icon(
                  onPressed: () => context.go(kNewClinicPath),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo consultorio'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ClinicFilterBar(),
            const SizedBox(height: 16),
            ...clinics.when(
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
                    onPressed: () => ref.invalidate(clinicSearchProvider),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [
                      if (hasFilters)
                        const Text(
                          'No hay consultorios que coincidan.',
                          key: Key('clinic-filter-empty'),
                        )
                      else
                        const Text('Todavía no hay consultorios registrados.'),
                    ]
                  : [for (final item in items) _ClinicTile(item)],
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object error) => switch (error) {
    ClinicSearchException(failure: ClinicSearchFailure.unauthenticated) =>
      'Tu sesión venció. Iniciá sesión nuevamente.',
    ClinicSearchException(failure: ClinicSearchFailure.forbidden) =>
      'Tu cuenta no tiene permiso para ver los consultorios.',
    ClinicSearchException(failure: ClinicSearchFailure.validation) =>
      apiMessageOf(error),
    _ => 'No pudimos cargar los consultorios. Intentá de nuevo.',
  };
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
