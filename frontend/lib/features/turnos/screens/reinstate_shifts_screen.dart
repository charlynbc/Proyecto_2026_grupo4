import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/shift.dart';
import '../models/shift_date_range.dart';
import '../models/shift_filters.dart';
import '../models/shift_state.dart';
import '../providers/doctors_provider.dart';
import '../providers/reinstatement_repository_provider.dart';
import '../providers/shift_repository_provider.dart';
import '../repositories/shift_reinstatement_repository.dart';

const String _cancelledAppointmentsWarning =
    'Las consultas que se cancelaron por la suspensión no se vuelven a '
    'agendar. Los socios tienen que pedir una nueva consulta.';

/// El funcionario elige turnos suspendidos de un rango y los vuelve a
/// habilitar. No cambia médico, especialidad, fecha, consultorio ni horarios.
class ReinstateShiftsScreen extends ConsumerStatefulWidget {
  const ReinstateShiftsScreen({super.key});

  @override
  ConsumerState<ReinstateShiftsScreen> createState() =>
      _ReinstateShiftsScreenState();
}

class _ReinstateShiftsScreenState extends ConsumerState<ReinstateShiftsScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  int? _doctorId;
  int? _specialtyId;
  DateTime? _fromDate;
  DateTime? _toDate;
  List<Shift> _shifts = const [];
  final List<int> _selected = [];
  bool _sending = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final from = parseUiDate(_fromController.text.trim());
    final to = parseUiDate(_toController.text.trim());
    if (_doctorId == null || _specialtyId == null || from == null || to == null) {
      return;
    }
    final repository = await ref.read(shiftRepositoryProvider.future);
    final page = await repository.listShifts(
      ShiftFilters(
        doctorId: _doctorId,
        specialtyId: _specialtyId,
        fromDate: from,
        toDate: to,
        state: ShiftState.suspended,
      ),
    );
    if (!mounted) return;
    setState(() {
      _fromDate = from;
      _toDate = to;
      _shifts = page.items;
      _selected.removeWhere((id) => !_shifts.any((shift) => shift.id == id));
    });
  }

  void _toggle(int id, bool selected) {
    setState(() {
      if (selected) {
        if (!_selected.contains(id)) _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  void _openDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: const Text(_cancelledAppointmentsWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('No rehabilitar'),
            ),
            TextButton(
              onPressed: () => _confirm(dialogContext),
              child: const Text('Volver a habilitar'),
            ),
          ],
        );
      },
    );
  }

  /// El diálogo sigue abierto hasta el próximo frame, así el segundo toque
  /// llega al botón. [_sending] se prende en el acto y ese toque no llama
  /// de nuevo. La rehabilitación corre una sola vez, en ese frame.
  void _confirm(BuildContext dialogContext) {
    if (_sending) return;
    _sending = true;
    final selected = List<int>.of(_selected);
    final doctorId = _doctorId!;
    final specialtyId = _specialtyId!;
    final fromDate = _fromDate!;
    final toDate = _toDate!;
    WidgetsBinding.instance
      ..scheduleFrame()
      ..addPostFrameCallback((_) async {
        try {
          final repository = await ref.read(
            reinstatementRepositoryProvider.future,
          );
          await repository.reinstate(
            ShiftReinstatement(
              doctorId: doctorId,
              specialtyId: specialtyId,
              fromDate: fromDate,
              toDate: toDate,
              shiftIds: selected,
            ),
          );
          if (!mounted || !dialogContext.mounted) return;
          Navigator.of(dialogContext).pop();
          await _search();
        } catch (error) {
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(apiMessageOf(error))),
          );
        } finally {
          if (mounted) setState(() => _sending = false);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final doctors = ref.watch(doctorsProvider).value ?? const [];
    final specialties = ref.watch(specialtiesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Rehabilitar fechas')),
      body: CenteredContent(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int?>(
              key: const Key('reinstate-doctor'),
              initialValue: null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Médico'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Elegí')),
                for (final doctor in doctors)
                  DropdownMenuItem(
                    value: doctor.id,
                    child: Text(doctor.fullName),
                  ),
              ],
              onChanged: (value) => setState(() => _doctorId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: const Key('reinstate-specialty'),
              initialValue: null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Especialidad'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Elegí')),
                for (final specialty in specialties)
                  DropdownMenuItem(
                    value: specialty.id,
                    child: Text(specialty.name),
                  ),
              ],
              onChanged: (value) => setState(() => _specialtyId = value),
            ),
            const SizedBox(height: 12),
            UiDateField(
              controller: _fromController,
              label: 'Desde',
              pickerHelpText: 'Fecha desde',
              pickerTooltip: 'Elegir la fecha desde',
              firstDate: kShiftDatePickerFirstDate,
              lastDate: kShiftDatePickerLastDate,
            ),
            const SizedBox(height: 12),
            UiDateField(
              controller: _toController,
              label: 'Hasta',
              pickerHelpText: 'Fecha hasta',
              pickerTooltip: 'Elegir la fecha hasta',
              firstDate: kShiftDatePickerFirstDate,
              lastDate: kShiftDatePickerLastDate,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _search, child: const Text('Buscar')),
            const SizedBox(height: 16),
            for (final shift in _shifts)
              Row(
                children: [
                  Checkbox(
                    value: _selected.contains(shift.id),
                    onChanged: (value) => _toggle(shift.id, value ?? false),
                  ),
                  Text(formatUiDate(shift.date)),
                ],
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selected.isEmpty ? null : _openDialog,
              child: const Text('Rehabilitar turnos'),
            ),
          ],
        ),
      ),
    );
  }
}
