import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_date.dart';
import '../models/shift.dart';
import '../models/shift_number.dart';
import '../models/weekday_names.dart';
import '../providers/suspend_shifts_controller.dart';
import '../providers/suspension_candidates_provider.dart';

/// Las fechas que se pueden suspender para lo buscado, con una casilla por
/// fecha (RF-14).
class SuspendShiftsList extends ConsumerWidget {
  const SuspendShiftsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(suspendShiftsControllerProvider).filter;
    if (filter == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Elegí el médico, la especialidad y las fechas, y tocá "Buscar".',
        ),
      );
    }

    final candidates = ref.watch(suspensionCandidatesProvider(filter));
    final colorScheme = Theme.of(context).colorScheme;
    return candidates.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => error is TooManySuspensionCandidatesException
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                error.message,
                style: TextStyle(color: colorScheme.error),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No pudimos cargar las fechas. Intentá de nuevo.',
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(suspensionCandidatesProvider(filter)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
      data: (shifts) => shifts.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No hay fechas activas para suspender con esos filtros. '
                'Cambiá el rango y buscá de nuevo.',
              ),
            )
          : _Dates(shifts),
    );
  }
}

class _Dates extends ConsumerWidget {
  const _Dates(this.shifts);

  final List<Shift> shifts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      suspendShiftsControllerProvider.select((s) => s.selectedIds),
    );
    final controller = ref.read(suspendShiftsControllerProvider.notifier);
    final allSelected = shifts.every((s) => selected.contains(s.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: const Key('suspend-select-all'),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Seleccionar todas'),
          subtitle: Text('Elegidas: ${selected.length}'),
          value: allSelected,
          onChanged: (value) => value == true
              ? controller.selectAll([for (final s in shifts) s.id])
              : controller.clearSelection(),
        ),
        const Divider(height: 1),
        for (final shift in shifts)
          CheckboxListTile(
            key: Key('suspend-check-${shift.id}'),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              '${weekdayLabel(shift.date.weekday)} ${formatUiDate(shift.date)}',
            ),
            subtitle: Text(
              '${ShiftNumber.formatTime(shift.startMinutes)} a '
              '${ShiftNumber.formatTime(shift.endMinutes)} · '
              '${shift.clinic.name}',
            ),
            value: selected.contains(shift.id),
            onChanged: (_) => controller.toggleSelection(shift.id),
          ),
      ],
    );
  }
}
