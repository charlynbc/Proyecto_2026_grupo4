import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_date.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../agenda/models/agenda_time.dart';
import '../models/doctor_shift.dart';
import '../models/doctor_shift_cancellation_result.dart';
import '../providers/doctor_agenda_controller.dart';
import '../providers/doctor_cancellation_repository_provider.dart';
import '../repositories/doctor_cancellation_repository.dart';
import 'cancel_with_reason_dialog.dart';

class CancelShiftButton extends ConsumerWidget {
  const CancelShiftButton({super.key, required this.shift});
  final DoctorShift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = parseApiDate(shift.date);
    if (shift.status != 'ACTIVO' || date.isBefore(UruguayTime.today())) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: Key('cancel-shift-${shift.id}'),
      tooltip: 'Cancelar turno',
      icon: const Icon(Icons.event_busy_outlined),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final result =
            await showCancelWithReasonDialog<DoctorShiftCancellationResult>(
              context: context,
              title: '¿Cancelar todo el turno?',
              body:
                  'Se cancelan todas las consultas agendadas del turno del ${formatUiDate(date)}, de ${shift.startTime} a ${shift.endTime} (${shift.specialtyName}), y la fecha queda suspendida: deja de ofrecer números. Las demás fechas del turno no se afectan. Se avisa a cada socio con el motivo que escribas. Rehabilitar la fecha después no restaura las consultas canceladas.',
              confirmLabel: 'Cancelar turno',
              onConfirm: (reason) async {
                final repository = await ref.read(
                  doctorCancellationRepositoryProvider.future,
                );
                return repository.cancelShift(shift.id, reason);
              },
              onError: (error) {
                if (error is DoctorCancellationException &&
                    (error.failure == DoctorCancellationFailure.notFound ||
                        error.failure ==
                            DoctorCancellationFailure.shiftNotCancellable)) {
                  ref.read(doctorAgendaControllerProvider.notifier).refresh();
                }
              },
            );
        if (result == null || !context.mounted) return;
        final count = result.cancelledCount;
        final passes = result.returnedReferralsCount;
        final message = count == 0
            ? 'Turno cancelado. No había consultas agendadas.'
            : count == 1
            ? 'Turno cancelado. Se canceló 1 consulta.'
            : 'Turno cancelado. Se cancelaron $count consultas.';
        final suffix = passes == 0
            ? ''
            : passes == 1
            ? ' 1 pase volvió a estar disponible.'
            : ' $passes pases volvieron a estar disponibles.';
        messenger.showSnackBar(SnackBar(content: Text('$message$suffix')));
        ref.read(doctorAgendaControllerProvider.notifier).refresh();
      },
    );
  }
}
