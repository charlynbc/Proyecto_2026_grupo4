import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../models/doctor.dart';
import '../models/shift_date_range.dart';
import '../models/suspension_filter.dart';
import '../providers/doctors_provider.dart';
import '../providers/suspend_shifts_controller.dart';
import '../providers/suspension_clock_provider.dart';

const String _invalidRangeMessage =
    'La fecha "Desde" no puede ser posterior a la fecha "Hasta".';

/// Lo que se elige para buscar las fechas a suspender (RF-14): médico,
/// especialidad (una de las del médico) y rango de fechas. "Desde" arranca en
/// hoy y, al buscar, se muestra ya ajustado a hoy si era anterior.
class SuspendShiftsSelector extends ConsumerStatefulWidget {
  const SuspendShiftsSelector({super.key});

  @override
  ConsumerState<SuspendShiftsSelector> createState() =>
      _SuspendShiftsSelectorState();
}

class _SuspendShiftsSelectorState extends ConsumerState<SuspendShiftsSelector> {
  late final TextEditingController _fromController;
  final TextEditingController _toController = TextEditingController();
  int? _doctorId;
  int? _specialtyId;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(
      text: formatUiDate(ref.read(suspensionClockProvider)()),
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _search() {
    // Tocar "Buscar" no mueve el foco del campo de fecha: se lo suelta acá
    // para que el campo muestre su error si la fecha quedó a medias.
    FocusScope.of(context).unfocus();

    final from = parseUiDate(_fromController.text.trim());
    final to = parseUiDate(_toController.text.trim());
    if (_doctorId == null ||
        _specialtyId == null ||
        from == null ||
        to == null) {
      return;
    }
    if (from.isAfter(to)) {
      setState(() => _rangeError = _invalidRangeMessage);
      return;
    }
    setState(() => _rangeError = null);

    ref
        .read(suspendShiftsControllerProvider.notifier)
        .setFilter(
          SuspensionFilter(
            doctorId: _doctorId!,
            specialtyId: _specialtyId!,
            fromDate: from,
            toDate: to,
          ),
        );
    // Se muestra el "desde" que quedó vigente (ajustado a hoy).
    final applied = ref.read(suspendShiftsControllerProvider).filter;
    if (applied != null) _fromController.text = formatUiDate(applied.fromDate);
  }

  @override
  Widget build(BuildContext context) {
    final doctors = ref.watch(doctorsProvider).value ?? const <Doctor>[];
    final today = ref.watch(suspensionClockProvider);
    final doctor = doctors.where((d) => d.id == _doctorId).firstOrNull;
    final canSearch =
        doctor != null &&
        _specialtyId != null &&
        parseUiDate(_fromController.text.trim()) != null &&
        parseUiDate(_toController.text.trim()) != null;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<int>(
            key: const Key('suspend-doctor'),
            initialValue: doctor?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Médico'),
            items: [
              for (final d in doctors)
                DropdownMenuItem(value: d.id, child: Text(d.fullName)),
            ],
            onChanged: (value) => setState(() {
              _doctorId = value;
              // La especialidad tiene que ser una de las del médico.
              _specialtyId = null;
            }),
          ),
        ),
        SizedBox(
          width: 240,
          // Con otro médico se arma de nuevo, para que no quede elegida una
          // especialidad que no es suya.
          child: KeyedSubtree(
            key: ValueKey('specialties-of-$_doctorId'),
            child: DropdownButtonFormField<int>(
              key: const Key('suspend-specialty'),
              initialValue: _specialtyId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Especialidad'),
              items: [
                for (final s in doctor?.specialties ?? const [])
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: doctor == null
                  ? null
                  : (value) => setState(() => _specialtyId = value),
            ),
          ),
        ),
        SizedBox(
          width: 220,
          child: UiDateField(
            controller: _fromController,
            label: 'Desde',
            pickerHelpText: 'Fecha desde',
            pickerTooltip: 'Elegir la fecha desde',
            firstDate: today(),
            lastDate: kShiftDatePickerLastDate,
            today: today,
            onChanged: (_) => setState(() => _rangeError = null),
          ),
        ),
        SizedBox(
          width: 220,
          child: UiDateField(
            controller: _toController,
            label: 'Hasta',
            pickerHelpText: 'Fecha hasta',
            pickerTooltip: 'Elegir la fecha hasta',
            firstDate: today(),
            lastDate: kShiftDatePickerLastDate,
            today: today,
            initialPickerDate: () => parseUiDate(_fromController.text),
            // El único error que pone el selector: el rango entre las dos
            // fechas, que ningún campo puede saber por sí solo.
            errorText: _rangeError,
            onChanged: (_) => setState(() => _rangeError = null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            key: const Key('suspend-search'),
            onPressed: canSearch ? _search : null,
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
        ),
      ],
    );
  }
}
