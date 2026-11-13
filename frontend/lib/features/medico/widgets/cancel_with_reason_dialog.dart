import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';

/// Pide un motivo y confirma una cancelación. Lo reutiliza la cancelación
/// del turno completo. Devuelve lo que devuelve [onConfirm], o null si se
/// cierra sin confirmar.
Future<T?> showCancelWithReasonDialog<T>({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  required Future<T> Function(String reason) onConfirm,
  void Function(Object error)? onError,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CancelWithReasonDialog<T>(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
      onError: onError,
    ),
  );
}

class _CancelWithReasonDialog<T> extends StatefulWidget {
  const _CancelWithReasonDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onError,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final Future<T> Function(String reason) onConfirm;
  final void Function(Object error)? onError;

  @override
  State<_CancelWithReasonDialog<T>> createState() =>
      _CancelWithReasonDialogState<T>();
}

class _CancelWithReasonDialogState<T>
    extends State<_CancelWithReasonDialog<T>> {
  final _reason = TextEditingController();
  bool _sending = false;
  String? _fieldError;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_sending) return;
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _fieldError = 'Escribí el motivo de la cancelación.');
      return;
    }
    setState(() {
      _sending = true;
      _fieldError = null;
      _error = null;
    });
    try {
      final value = await widget.onConfirm(reason);
      if (!mounted) return;
      Navigator.of(context).pop(value);
    } catch (error) {
      widget.onError?.call(error);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = apiMessageOf(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        scrollable: true,
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.body),
            const SizedBox(height: 12),
            TextField(
              key: const Key('cancel-reason-field'),
              controller: _reason,
              enabled: !_sending,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Motivo de la cancelación',
                errorText: _fieldError,
                errorMaxLines: 2,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, key: const Key('cancel-dialog-error')),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('dismiss-cancel-dialog'),
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
          FilledButton(
            key: const Key('confirm-cancel'),
            onPressed: _sending ? null : _confirm,
            child: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
