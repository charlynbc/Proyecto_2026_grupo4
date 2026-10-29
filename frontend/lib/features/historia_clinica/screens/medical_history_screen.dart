import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../models/medical_history_entry.dart';
import '../models/medical_history_query.dart';
import '../providers/medical_history_filters_controller.dart';
import '../providers/medical_history_options_provider.dart';
import '../providers/medical_history_provider.dart';

/// Listado y filtros de las atenciones registradas del socio.
class MedicalHistoryScreen extends ConsumerStatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  ConsumerState<MedicalHistoryScreen> createState() =>
      _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends ConsumerState<MedicalHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _textController = TextEditingController();
  int? _specialtyId;
  int? _doctorId;
  MedicalHistoryOrder _order = MedicalHistoryOrder.date;
  MedicalHistoryDirection _direction = MedicalHistoryDirection.descending;
  String? _rangeError;
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final query = ref.read(medicalHistoryFiltersProvider);
    _fromController.text = query.from == null ? '' : formatUiDate(query.from!);
    _toController.text = query.to == null ? '' : formatUiDate(query.to!);
    _textController.text = query.text ?? '';
    _specialtyId = query.specialtyId;
    _doctorId = query.doctorId;
    _order = query.order;
    _direction = query.direction;
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _apply() {
    setState(() {
      _showErrors = true;
      _rangeError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final from = parseUiDate(_fromController.text.trim());
    final to = parseUiDate(_toController.text.trim());
    if (from != null && to != null && from.isAfter(to)) {
      setState(() {
        _rangeError =
            'La fecha "Desde" no puede ser posterior a la fecha "Hasta".';
      });
      return;
    }
    final controller = ref.read(medicalHistoryFiltersProvider.notifier);
    controller.apply(
      from: from,
      to: to,
      specialtyId: _specialtyId,
      doctorId: _doctorId,
      text: _textController.text.trim(),
    );
    controller.sortBy(_order, direction: _direction);
  }

  void _clear() {
    // reset puede invocar onChanged con los valores iniciales de los campos.
    // Lo hacemos antes de fijar los valores definitivos de la consulta limpia.
    _formKey.currentState!.reset();
    _fromController.clear();
    _toController.clear();
    _textController.clear();
    setState(() {
      _specialtyId = null;
      _doctorId = null;
      _order = MedicalHistoryOrder.date;
      _direction = MedicalHistoryDirection.descending;
      _rangeError = null;
      _showErrors = false;
    });
    ref.read(medicalHistoryFiltersProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(medicalHistoryProvider);
    final options = ref.watch(medicalHistoryOptionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi historia clínica')),
      body: CenteredContent(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('medical-history-text'),
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar en el tratamiento',
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _apply(),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 600
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: width,
                            child: UiDateField(
                              key: const Key('medical-history-from'),
                              controller: _fromController,
                              label: 'Desde',
                              pickerHelpText: 'Fecha inicial',
                              pickerTooltip: 'Elegir fecha inicial',
                              firstDate: DateTime.utc(1900),
                              lastDate: DateTime.utc(2100, 12, 31),
                              showErrorsNow: () => _showErrors,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: UiDateField(
                              key: const Key('medical-history-to'),
                              controller: _toController,
                              label: 'Hasta',
                              pickerHelpText: 'Fecha final',
                              pickerTooltip: 'Elegir fecha final',
                              firstDate: DateTime.utc(1900),
                              lastDate: DateTime.utc(2100, 12, 31),
                              showErrorsNow: () => _showErrors,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            key: const Key('medical-history-specialty'),
                            child: _specialtySelector(options),
                          ),
                          SizedBox(
                            width: width,
                            key: const Key('medical-history-doctor'),
                            child: _doctorSelector(options),
                          ),
                          SizedBox(
                            width: width,
                            key: const Key('medical-history-order'),
                            child: DropdownButtonFormField<MedicalHistoryOrder>(
                              key: ValueKey(('medical-history-order', _order)),
                              initialValue: _order,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Ordenar por',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: MedicalHistoryOrder.date,
                                  child: Text('Fecha'),
                                ),
                                DropdownMenuItem(
                                  value: MedicalHistoryOrder.specialty,
                                  child: Text('Especialidad'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) setState(() => _order = value);
                              },
                            ),
                          ),
                          SizedBox(
                            width: width,
                            key: const Key('medical-history-direction'),
                            child: DropdownButtonFormField<MedicalHistoryDirection>(
                              key: ValueKey(('medical-history-direction', _direction)),
                              initialValue: _direction,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Sentido',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: MedicalHistoryDirection.ascending,
                                  child: Text('Ascendente'),
                                ),
                                DropdownMenuItem(
                                  value: MedicalHistoryDirection.descending,
                                  child: Text('Descendente'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _direction = value);
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_rangeError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _rangeError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (options.hasError) ...[
                    const SizedBox(height: 12),
                    _error(
                      options.error!,
                      () => ref.invalidate(medicalHistoryOptionsProvider),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton(onPressed: _apply, child: const Text('Aplicar filtros')),
                      OutlinedButton(onPressed: _clear, child: const Text('Limpiar')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            history.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _error(
                error,
                () => ref.invalidate(medicalHistoryProvider),
              ),
              data: (entries) => entries.isEmpty
                  ? const Text('No hay atenciones para mostrar con estos filtros.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [for (final entry in entries) _card(entry)],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specialtySelector(AsyncValue<MedicalHistoryOptions> options) {
    final items = options.asData?.value.specialties ?? [];
    return DropdownButtonFormField<int>(
      key: ValueKey(('medical-history-specialty', _specialtyId, items.length)),
      initialValue: items.any((item) => item.id == _specialtyId) ? _specialtyId : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Especialidad'),
      items: [
        const DropdownMenuItem<int>(child: Text('Todas')),
        for (final item in items)
          DropdownMenuItem(value: item.id, child: Text(item.name)),
      ],
      onChanged: options.isLoading ? null : (value) => setState(() => _specialtyId = value),
    );
  }

  Widget _doctorSelector(AsyncValue<MedicalHistoryOptions> options) {
    final items = options.asData?.value.doctors ?? <int, String>{};
    return DropdownButtonFormField<int>(
      key: ValueKey(('medical-history-doctor', _doctorId, items.length)),
      initialValue: items.containsKey(_doctorId) ? _doctorId : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Médico'),
      items: [
        const DropdownMenuItem<int>(child: Text('Todos')),
        for (final item in items.entries)
          DropdownMenuItem(value: item.key, child: Text(item.value)),
      ],
      onChanged: options.isLoading ? null : (value) => setState(() => _doctorId = value),
    );
  }

  Widget _card(MedicalHistoryEntry entry) => Card(
    key: ValueKey('medical-history-entry-${entry.id}'),
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatUiDate(entry.attendedOn), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(entry.doctorFullName),
          Text(entry.specialty.name),
          const SizedBox(height: 8),
          Text(entry.condition),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/socio/historia/${entry.id}'),
            child: const Text('Ver detalle'),
          ),
        ],
      ),
    ),
  );

  Widget _error(Object error, VoidCallback retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(apiMessageOf(error), style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: retry, child: const Text('Reintentar')),
    ],
  );
}
