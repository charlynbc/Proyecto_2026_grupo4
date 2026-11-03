import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../models/appointment.dart';
import '../providers/appointment_cancellation_provider.dart';
import '../providers/appointment_history_provider.dart';
import '../repositories/appointment_cancellation_repository.dart';

Future<void> showCancelAppointmentDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Appointment appointment,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CancelAppointmentDialog(ref: ref, appointment: appointment),
);

class _CancelAppointmentDialog extends ConsumerStatefulWidget {
  const _CancelAppointmentDialog({
    required this.ref,
    required this.appointment,
  });

  final WidgetRef ref;
  final Appointment appointment;

  @override
  ConsumerState<_CancelAppointmentDialog> createState() =>
      _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState
    extends ConsumerState<_CancelAppointmentDialog> {
  bool _sending = false;
  bool _sendStarted = false;
  String? _error;

  Future<void> _cancel() async {
    if (_sendStarted) return;
    _sendStarted = true;
    setState(() {
      _sending = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await widget.ref.read(
        appointmentCancellationRepositoryProvider.future,
      );
      final result = await repository.cancel(widget.appointment.id);
      if (!mounted) return;
      navigator.pop();
      widget.ref.read(appointmentHistoryRefreshProvider.notifier).refresh();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.referralReturned
                ? 'Consulta cancelada. Recuperaste tu pase.'
                : 'Consulta cancelada.',
          ),
        ),
      );
    } on CancellationException catch (error) {
      if (!mounted) return;
      final String message;
      switch (error.failure) {
        case CancellationFailure.unauthenticated:
          message = 'Tu sesión venció. Iniciá sesión nuevamente.';
        case CancellationFailure.forbidden:
          message = 'Tu cuenta no tiene permiso para cancelar consultas.';
        case CancellationFailure.notScheduled:
        case CancellationFailure.notFound:
          message = apiMessageOf(error);
          widget.ref.read(appointmentHistoryRefreshProvider.notifier).refresh();
        default:
          message = apiMessageOf(error);
      }
      setState(() {
        _sending = false;
        _sendStarted = false;
        _error = message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendStarted = false;
        _error = apiMessageOf(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: const Text('¿Cancelar la consulta?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${appointment.specialty.name}. '
              '${formatUiDate(appointment.date)}',
            ),
            if (appointment.referralId != null) ...[
              const SizedBox(height: 8),
              const Text('Si el pase sigue vigente, lo recuperás.'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const Key('cancel-error')),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('dismiss-cancel-dialog'),
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
          OutlinedButton(
            key: const Key('confirm-cancel-appointment'),
            onPressed: _sending ? null : _cancel,
            child: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancelar consulta'),
          ),
        ],
      ),
    );
  }
}
