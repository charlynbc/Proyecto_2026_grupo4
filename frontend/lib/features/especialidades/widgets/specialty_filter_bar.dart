import 'package:flutter/material.dart';

import '../models/specialty_filters.dart';

/// Nombre y pase se aplican con Buscar; criterio y sentido son inmediatos.
class SpecialtyFilterBar extends StatefulWidget {
  const SpecialtyFilterBar({
    required this.onSearch,
    required this.onClear,
    required this.order,
    required this.ascending,
    required this.onSort,
    super.key,
  });

  final ValueChanged<SpecialtyFilters> onSearch;
  final VoidCallback onClear;
  final SpecialtyOrder order;
  final bool ascending;
  final void Function(SpecialtyOrder order, bool ascending) onSort;

  @override
  State<SpecialtyFilterBar> createState() => _SpecialtyFilterBarState();
}

class _SpecialtyFilterBarState extends State<SpecialtyFilterBar> {
  final _nameController = TextEditingController();
  bool? _requiresReferral;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    widget.onSearch(
      SpecialtyFilters(
        name: name.isEmpty ? null : name,
        requiresReferral: _requiresReferral,
        order: widget.order,
        ascending: widget.ascending,
      ),
    );
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    _nameController.clear();
    // Los valores iniciales actualizados sincronizan también los FormField.
    setState(() {
      _requiresReferral = null;
    });
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: const Key('specialty-filter-name'),
          controller: _nameController,
          maxLength: 120,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onFieldSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 500
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(width: width, child: _referralField()),
                SizedBox(width: width, child: _orderField()),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton(
              key: const Key('specialty-filter-search'),
              onPressed: _search,
              child: const Text('Buscar'),
            ),
            OutlinedButton(
              key: const Key('specialty-filter-clear'),
              onPressed: _clear,
              child: const Text('Limpiar'),
            ),
            TextButton.icon(
              key: const Key('specialty-filter-direction'),
              onPressed: () => widget.onSort(widget.order, !widget.ascending),
              icon: Icon(
                widget.ascending ? Icons.arrow_upward : Icons.arrow_downward,
              ),
              label: Text(widget.ascending ? 'Ascendente' : 'Descendente'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _referralField() => DropdownButtonFormField<bool>(
    key: const Key('specialty-filter-referral'),
    initialValue: _requiresReferral,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Requiere pase'),
    items: const [
      DropdownMenuItem<bool>(child: Text('Todas')),
      DropdownMenuItem(value: true, child: Text('Sí')),
      DropdownMenuItem(value: false, child: Text('No')),
    ],
    onChanged: (value) => setState(() => _requiresReferral = value),
  );

  Widget _orderField() => DropdownButtonFormField<SpecialtyOrder>(
    key: const Key('specialty-filter-order'),
    initialValue: widget.order,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'Ordenar por'),
    items: const [
      DropdownMenuItem(value: SpecialtyOrder.name, child: Text('Nombre')),
      DropdownMenuItem(
        value: SpecialtyOrder.createdAt,
        child: Text('Fecha de alta'),
      ),
    ],
    onChanged: (value) {
      if (value != null) {
        widget.onSort(value, widget.ascending);
      }
    },
  );
}
