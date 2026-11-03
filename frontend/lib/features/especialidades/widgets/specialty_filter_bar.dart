import 'package:flutter/material.dart';

import '../models/specialty_filters.dart';

/// Controles de RF-36: solo Buscar y Limpiar comunican acciones al listado.
class SpecialtyFilterBar extends StatefulWidget {
  const SpecialtyFilterBar({
    required this.onSearch,
    required this.onClear,
    super.key,
  });

  final ValueChanged<SpecialtyFilters> onSearch;
  final VoidCallback onClear;

  @override
  State<SpecialtyFilterBar> createState() => _SpecialtyFilterBarState();
}

class _SpecialtyFilterBarState extends State<SpecialtyFilterBar> {
  final _nameController = TextEditingController();
  bool? _requiresReferral;
  SpecialtyOrder _order = SpecialtyOrder.name;

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
        order: _order,
      ),
    );
  }

  void _clear() {
    FocusScope.of(context).unfocus();
    _nameController.clear();
    // Los valores iniciales actualizados sincronizan también los FormField.
    setState(() {
      _requiresReferral = null;
      _order = SpecialtyOrder.name;
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
                SizedBox(
                  width: width,
                  child: _referralField(),
                ),
                SizedBox(
                  width: width,
                  child: _orderField(),
                ),
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
    initialValue: _order,
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
        setState(() => _order = value);
      }
    },
  );
}
