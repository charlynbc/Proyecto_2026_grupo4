import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor_cancellation_result.dart';
import '../models/doctor_shift.dart';
import '../providers/doctor_agenda_controller.dart';
import '../providers/doctor_cancellation_repository_provider.dart';
import '../repositories/doctor_cancellation_repository.dart';
import 'cancel_with_reason_dialog.dart';

/// Acciones de un número. Hoy solo cancelar una consulta agendada (RF-27).
class DoctorNumberActions extends ConsumerWidget {
  const DoctorNumberActions({super.key, required this.item});

  final DoctorShiftNumber item;

  bool get _canCancel =>
      item.appointmentId != null && item.appointmentStatus == 'AGENDADA';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_canCancel) return const SizedBox.shrink();
    final appointmentId = item.appointmentId!;
    final patient = item.patient;
    final name = patient == null
        ? 'esta consulta'
        : '${patient.name} ${patient.lastName}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: Key('cancel-appointment-$appointmentId'),
          tooltip: 'Cancelar consulta',
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => _cancel(context, ref, appointmentId, name),
          icon: const Icon(Icons.event_busy_outlined),
        ),
      ],
    );
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    int appointmentId,
    String name,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showCancelWithReasonDialog<DoctorCancellationResult>(
      context: context,
      title: '¿Cancelar la consulta?',
      body:
          'Se cancela la consulta de $name. Se le avisa al socio por '
          'notificación, con el motivo que escribas.',
      confirmLabel: 'Cancelar consulta',
      onConfirm: (reason) async {
        final repository = await ref.read(
          doctorCancellationRepositoryProvider.future,
        );
        return repository.cancelAppointment(appointmentId, reason);
      },
      onError: (error) {
        if (error is! DoctorCancellationException) return;
        if (error.failure != DoctorCancellationFailure.notFound &&
            error.failure != DoctorCancellationFailure.notScheduled) {
          return;
        }
        ref.read(doctorAgendaControllerProvider.notifier).refresh();
      },
    );
    if (result == null) return;
    final notice = result.referralReturned
        ? 'Consulta cancelada. Se le avisará al socio. El pase volvió a estar disponible.'
        : 'Consulta cancelada. Se le avisará al socio.';
    messenger.showSnackBar(SnackBar(content: Text(notice)));
    ref.read(doctorAgendaControllerProvider.notifier).refresh();
  }
}
