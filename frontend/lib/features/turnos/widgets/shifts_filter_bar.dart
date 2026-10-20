import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/shift_date_range.dart';
import '../models/shift_filters.dart';
import '../models/shift_state.dart';
import '../models/weekday_names.dart';
import '../providers/doctors_provider.dart';
import '../providers/shift_filters_controller.dart';

const String _invalidRangeMessage =
    'La fecha "Desde" no puede ser posterior a la fecha "Hasta".';

/// Filtros de la consulta de turnos (RF-17): médico, especialidad, día de la
/// semana, rango de fechas y estado se aplican juntos con "Buscar"; el orden
/// se aplica apenas se cambia.
///
/// El error de formato de una fecha (mal escrita o inexistente) lo muestra el
/// propio campo, y es la única fuente: la barra no arma el suyo. La barra solo
/// agrega el error de rango, que ningún campo puede saber por sí solo.
class ShiftsFilterBar extends ConsumerStatefulWidget {
  const ShiftsFilterBar({super.key});

  @override
  ConsumerState<ShiftsFilterBar> createState() => _ShiftsFilterBarState();
}

class _ShiftsFilterBarState extends ConsumerState<ShiftsFilterBar> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  int? _doctorId;
  int? _specialtyId;
  int? _weekday;
  ShiftState? _state;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    final applied = ref.read(shiftFiltersControllerProvider);
    _fromController = TextEditingController(
      text: applied.fromDate == null ? '' : formatUiDate(applied.fromDate!),
    );
    _toController = TextEditingController(
      text: applied.toDate == null ? '' : formatUiDate(applied.toDate!),
    );
    _doctorId = applied.doctorId;
    _specialtyId = applied.specialtyId;
    _weekday = applied.weekday;
    _state = applied.state;
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _clearRangeError() {
    if (_rangeError != null) setState(() => _rangeError = null);
  }

  void _search() {
    // Tocar "Buscar" no mueve el foco del campo de fecha: se lo suelta acá
    // para que el campo muestre su error si la fecha quedó a medias.
    FocusScope.of(context).unfocus();

    final fromText = _fromController.text.trim();
    final toText = _toController.text.trim();
    // Con una fecha mal escrita o inexistente no se busca; el error ya lo
    // muestra el campo.
    if (uiDateError(fromText) != null || uiDateError(toText) != null) return;

    final from = fromText.isEmpty ? null : parseUiDate(fromText);
    final to = toText.isEmpty ? null : parseUiDate(toText);
    if (from != null && to != null && from.isAfter(to)) {
      setState(() => _rangeError = _invalidRangeMessage);
      return;
    }
    setState(() => _rangeError = null);

    ref
        .read(shiftFiltersControllerProvider.notifier)
        .search(
          doctorId: _doctorId,
          specialtyId: _specialtyId,
          weekday: _weekday,
          fromDate: from,
          toDate: to,
          shiftState: _state,
        );
  }

  @override
  Widget build(BuildContext context) {
    final applied = ref.watch(shiftFiltersControllerProvider);
    final controller = ref.read(shiftFiltersControllerProvider.notifier);
    final doctors = ref.watch(doctorsProvider).value ?? const [];
    final specialties = ref.watch(specialtiesProvider).value ?? const [];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<int?>(
            key: const Key('filter-doctor'),
            initialValue: doctors.any((d) => d.id == _doctorId)
                ? _doctorId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Médico'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (final doctor in doctors)
                DropdownMenuItem(
                  value: doctor.id,
                  child: Text(doctor.fullName),
                ),
            ],
            onChanged: (value) => setState(() => _doctorId = value),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<int?>(
            key: const Key('filter-specialty'),
            initialValue: specialties.any((s) => s.id == _specialtyId)
                ? _specialtyId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Especialidad'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              for (final specialty in specialties)
                DropdownMenuItem(
                  value: specialty.id,
                  child: Text(specialty.name),
                ),
            ],
            onChanged: (value) => setState(() => _specialtyId = value),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<int?>(
            key: const Key('filter-weekday'),
            initialValue: _weekday,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Día de la semana'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (var day = 1; day <= 7; day++)
                DropdownMenuItem(value: day, child: Text(weekdayLabel(day))),
            ],
            onChanged: (value) => setState(() => _weekday = value),
          ),
        ),
        SizedBox(
          width: 220,
          child: UiDateField(
            controller: _fromController,
            label: 'Desde',
            pickerHelpText: 'Fecha desde',
            pickerTooltip: 'Elegir la fecha desde',
            firstDate: kShiftDatePickerFirstDate,
            lastDate: kShiftDatePickerLastDate,
            textInputAction: TextInputAction.search,
            onChanged: (_) => _clearRangeError(),
            onSubmitted: (_) => _search(),
          ),
        ),
        SizedBox(
          width: 220,
          child: UiDateField(
            controller: _toController,
            label: 'Hasta',
            pickerHelpText: 'Fecha hasta',
            pickerTooltip: 'Elegir la fecha hasta',
            firstDate: kShiftDatePickerFirstDate,
            lastDate: kShiftDatePickerLastDate,
            // El calendario de "Hasta" abre en la fecha de "Desde", si es válida.
            initialPickerDate: () => parseUiDate(_fromController.text),
            // El único error que pone la barra: el rango entre las dos fechas.
            errorText: _rangeError,
            textInputAction: TextInputAction.search,
            onChanged: (_) => _clearRangeError(),
            onSubmitted: (_) => _search(),
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<ShiftState?>(
            key: const Key('filter-state'),
            initialValue: _state,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (final state in ShiftState.values)
                DropdownMenuItem(value: state, child: Text(state.label)),
            ],
            onChanged: (value) => setState(() => _state = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            onPressed: _search,
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<ShiftOrder>(
            key: const Key('filter-order'),
            initialValue: applied.order,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ordenar por'),
            items: [
              for (final order in ShiftOrder.values)
                DropdownMenuItem(value: order, child: Text(order.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              controller.sortBy(value, ascending: applied.ascending);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextButton.icon(
            onPressed: () =>
                controller.sortBy(applied.order, ascending: !applied.ascending),
            icon: Icon(
              applied.ascending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            label: Text(applied.ascending ? 'Ascendente' : 'Descendente'),
          ),
        ),
      ],
    );
  }
}
