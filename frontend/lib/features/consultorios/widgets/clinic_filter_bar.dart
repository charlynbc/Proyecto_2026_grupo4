import 'package:flutter/material.dart';

import '../models/clinic_filters.dart';

/// Controles de RF-37: solo Buscar y Limpiar comunican acciones al listado.
class ClinicFilterBar extends StatefulWidget {
  const ClinicFilterBar({
    required this.onSearch,
    required this.onClear,
    super.key,
  });

  final ValueChanged<ClinicFilters> onSearch;
  final VoidCallback onClear;

  @override
  State<ClinicFilterBar> createState() => _ClinicFilterBarState();
}

class _ClinicFilterBarState extends State<ClinicFilterBar> {
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
    widget.onSearch(
      ClinicFilters(
        name: name.isEmpty ? null : name,
        location: location.isEmpty ? null : location,
        order: _order,
      ),
    );
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    _nameController.clear();
    _locationController.clear();
    setState(() => _order = ClinicOrder.name);
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
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
            if (value != null) setState(() => _order = value);
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
          ],
        ),
      ],
    );
  }
}
