import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../models/schedule_entry.dart';
import '../providers/schedules_page_provider.dart';
import '../providers/staff_cancellation_repository_provider.dart';
import '../repositories/staff_cancellation_repository.dart';

Future<void> showCancelScheduleDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ScheduleEntry entry,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CancelScheduleDialog(ref: ref, entry: entry),
);

class _CancelScheduleDialog extends ConsumerStatefulWidget {
  const _CancelScheduleDialog({required this.ref, required this.entry});

  final WidgetRef ref;
  final ScheduleEntry entry;

  @override
  ConsumerState<_CancelScheduleDialog> createState() =>
      _CancelScheduleDialogState();
}

class _CancelScheduleDialogState extends ConsumerState<_CancelScheduleDialog> {
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
        staffCancellationRepositoryProvider.future,
      );
      final result = await repository.cancel(widget.entry.appointmentId);
      if (!mounted) return;
      navigator.pop();
      widget.ref.invalidate(schedulesPageProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.referralReturned
                ? 'Consulta cancelada. El pase volvió a estar disponible.'
                : 'Consulta cancelada.',
          ),
        ),
      );
    } on StaffCancellationException catch (error) {
      if (!mounted) return;
      final String message;
      switch (error.failure) {
        case StaffCancellationFailure.unauthenticated:
          message = 'Tu sesión venció. Iniciá sesión nuevamente.';
        case StaffCancellationFailure.forbidden:
          message = 'Tu cuenta no tiene permiso para cancelar consultas.';
        case StaffCancellationFailure.notScheduled:
        case StaffCancellationFailure.notFound:
          message = apiMessageOf(error);
          widget.ref.invalidate(schedulesPageProvider);
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
    final entry = widget.entry;
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: const Text('¿Cancelar la consulta?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry.member.firstName} ${entry.member.lastName}'),
                Text(entry.specialty.name),
                Text(formatUiDate(entry.date)),
                Text(entry.startTime),
                const SizedBox(height: 8),
                const Text(
                  'La cancelación es a pedido del socio y se le avisa por notificación.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('cancel-schedule-error')),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('dismiss-cancel-schedule-dialog'),
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
          OutlinedButton(
            key: const Key('confirm-cancel-schedule'),
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
