import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_date.dart';
import '../models/shift_number.dart';
import '../models/weekday_names.dart';
import '../providers/suspend_shifts_controller.dart';

/// Confirmación de la suspensión (RF-14): las fechas, cuántas consultas se
/// cancelan y una observación opcional. Se cierra sola cuando el controller
/// descarta la vista previa (al volver, al suspender o ante un error que la
/// invalida).
class SuspendConfirmDialog extends ConsumerStatefulWidget {
  const SuspendConfirmDialog({super.key});

  @override
  ConsumerState<SuspendConfirmDialog> createState() =>
      _SuspendConfirmDialogState();
}

class _SuspendConfirmDialogState extends ConsumerState<SuspendConfirmDialog> {
  late final TextEditingController _observation;

  @override
  void initState() {
    super.initState();
    _observation = TextEditingController(
      text: ref.read(suspendShiftsControllerProvider).observation,
    );
  }

  @override
  void dispose() {
    _observation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(suspendShiftsControllerProvider.select((s) => s.preview), (
      _,
      preview,
    ) {
      if (preview == null && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    final state = ref.watch(suspendShiftsControllerProvider);
    final controller = ref.read(suspendShiftsControllerProvider.notifier);
    final preview = state.preview;
    // Un cuadro vacío mientras el diálogo se cierra.
    if (preview == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final idle = state.phase == SuspendPhase.idle;
    return AlertDialog(
      scrollable: true,
      title: const Text('Confirmar suspensión'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vas a suspender estas fechas:'),
          const SizedBox(height: 8),
          for (final date in preview.affectedDates)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${weekdayLabel(date.date.weekday)} '
                    '${formatUiDate(date.date)} · '
                    '${ShiftNumber.formatTime(date.startMinutes)} a '
                    '${ShiftNumber.formatTime(date.endMinutes)}',
                    style: textTheme.titleSmall,
                  ),
                  Text('Consultas a cancelar: ${date.appointmentsToCancel}'),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                '${preview.totalAppointments}',
                key: const Key('suspension-total'),
                style: textTheme.headlineMedium,
              ),
              const Text('consultas a cancelar en total'),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Se devuelven los pases y se avisa a cada socio afectado.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('suspension-observation'),
            controller: _observation,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Observación (opcional)',
              helperText: 'Se incluye en el aviso a cada socio.',
            ),
            onChanged: controller.setObservation,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${state.observation.length}/$kMaxSuspensionObservationLength',
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('suspension-dialog-error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.error!,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: idle ? controller.dismissPreview : null,
          child: const Text('Volver'),
        ),
        FilledButton(
          key: const Key('confirm-suspension'),
          onPressed: idle ? controller.confirm : null,
          child: idle
              ? const Text('Suspender fechas')
              : const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      ],
    );
  }
}
