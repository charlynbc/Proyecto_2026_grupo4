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

/// Por qué cancela el funcionario (RF-19).
enum _Cause { socio, other }

class _CancelScheduleDialog extends ConsumerStatefulWidget {
  const _CancelScheduleDialog({required this.ref, required this.entry});

  final WidgetRef ref;
  final ScheduleEntry entry;

  @override
  ConsumerState<_CancelScheduleDialog> createState() =>
      _CancelScheduleDialogState();
}

class _CancelScheduleDialogState extends ConsumerState<_CancelScheduleDialog> {
  final _reason = TextEditingController();
  _Cause _cause = _Cause.socio;
  bool _sending = false;
  bool _sendStarted = false;
  String? _fieldError;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _chooseCause(_Cause? cause) {
    if (_sending || cause == null) return;
    setState(() {
      _cause = cause;
      _fieldError = null;
      _error = null;
    });
  }

  Future<void> _cancel() async {
    if (_sendStarted) return;
    // Sin motivo es a pedido del socio. Por otro motivo el campo es
    // obligatorio; el servidor vuelve a validarlo.
    String? reason;
    if (_cause == _Cause.other) {
      reason = _reason.text.trim();
      if (reason.isEmpty) {
        setState(() => _fieldError = 'Escribí el motivo de la cancelación.');
        return;
      }
    }
    _sendStarted = true;
    setState(() {
      _sending = true;
      _fieldError = null;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await widget.ref.read(
        staffCancellationRepositoryProvider.future,
      );
      final result = await repository.cancel(
        widget.entry.appointmentId,
        reason: reason,
      );
      if (!mounted) return;
      navigator.pop();
      widget.ref.invalidate(schedulesPageProvider);
      final String message;
      if (reason == null) {
        message = result.referralReturned
            ? 'Consulta cancelada. El pase volvió a estar disponible.'
            : 'Consulta cancelada.';
      } else if (result.status == 'CANCELADA_INSTITUCION') {
        message = result.referralReturned
            ? 'Consulta cancelada por otro motivo. El socio puede ver el '
                  'motivo. El pase volvió a estar disponible.'
            : 'Consulta cancelada por otro motivo. El socio puede ver el '
                  'motivo.';
      } else {
        // El servidor canceló pero no guardó el motivo (todavía no lo
        // entiende): se avisa para que el funcionario le cuente al socio.
        message =
            'La consulta se canceló, pero el sistema no guardó el motivo. '
            'El socio no lo va a ver: avisale por otro medio.';
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: reason != null && result.status != 'CANCELADA_INSTITUCION'
              ? const Duration(seconds: 10)
              : const Duration(seconds: 4),
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
          message = error.message;
          widget.ref.invalidate(schedulesPageProvider);
        default:
          message = error.message;
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
                RadioGroup<_Cause>(
                  groupValue: _cause,
                  onChanged: _chooseCause,
                  child: Column(
                    children: [
                      RadioListTile<_Cause>(
                        key: const Key('cancel-cause-socio'),
                        contentPadding: EdgeInsets.zero,
                        enabled: !_sending,
                        value: _Cause.socio,
                        title: const Text('A pedido del socio'),
                      ),
                      RadioListTile<_Cause>(
                        key: const Key('cancel-cause-other'),
                        contentPadding: EdgeInsets.zero,
                        enabled: !_sending,
                        value: _Cause.other,
                        title: const Text(
                          'Otro motivo (administrativo u otro)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_cause == _Cause.other) ...[
                  TextField(
                    key: const Key('cancel-schedule-reason'),
                    controller: _reason,
                    enabled: !_sending,
                    maxLength: kStaffCancellationReasonMaxLength,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (_fieldError != null) {
                        setState(() => _fieldError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Motivo de la cancelación',
                      errorText: _fieldError,
                      errorMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El socio va a ver el motivo en el detalle de su consulta '
                    'y en la notificación.',
                  ),
                ] else
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
