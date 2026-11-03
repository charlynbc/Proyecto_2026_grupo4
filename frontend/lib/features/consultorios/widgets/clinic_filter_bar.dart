import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic_filters.dart';
import '../providers/clinic_filters_controller.dart';
import '../providers/clinic_search_provider.dart';

/// Controles de RF-37. El texto se aplica con Buscar o Enter en ubicación.
/// El orden y el sentido se aplican al cambiarlos.
class ClinicFilterBar extends ConsumerStatefulWidget {
  const ClinicFilterBar({super.key});

  @override
  ConsumerState<ClinicFilterBar> createState() => _ClinicFilterBarState();
}

class _ClinicFilterBarState extends ConsumerState<ClinicFilterBar> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  ClinicOrder _order = ClinicOrder.name;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    ref
        .read(clinicFiltersControllerProvider.notifier)
        .apply(
          name: name.isEmpty ? null : name,
          location: location.isEmpty ? null : location,
          order: _order,
        );
    ref.invalidate(clinicSearchProvider);
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    _nameController.clear();
    _locationController.clear();
    setState(() => _order = ClinicOrder.name);
    ref.read(clinicFiltersControllerProvider.notifier).clear();
    ref.invalidate(clinicSearchProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ascending = ref.watch(
      clinicFiltersControllerProvider.select((filters) => filters.ascending),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('clinic-filter-name'),
          controller: _nameController,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Nombre o número'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('clinic-filter-location'),
          controller: _locationController,
          maxLength: 200,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: 'Ubicación'),
          onFieldSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ClinicOrder>(
          key: const Key('clinic-filter-order'),
          initialValue: _order,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ordenar por'),
          items: const [
            DropdownMenuItem(value: ClinicOrder.name, child: Text('Nombre')),
            DropdownMenuItem(
              value: ClinicOrder.location,
              child: Text('Ubicación'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _order = value);
            ref.read(clinicFiltersControllerProvider.notifier).sortBy(value);
            ref.invalidate(clinicSearchProvider);
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const Key('clinic-filter-search'),
              onPressed: _search,
              child: const Text('Buscar'),
            ),
            OutlinedButton(
              key: const Key('clinic-filter-clear'),
              onPressed: _clear,
              child: const Text('Limpiar'),
            ),
            TextButton.icon(
              key: const Key('clinic-filter-direction'),
              onPressed: () => ref
                  .read(clinicFiltersControllerProvider.notifier)
                  .toggleDirection(),
              icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
              label: Text(ascending ? 'Ascendente' : 'Descendente'),
            ),
          ],
        ),
      ],
    );
  }
}
