import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/centered_content.dart';
import '../providers/suspend_shifts_controller.dart';
import '../widgets/suspend_confirm_dialog.dart';
import '../widgets/suspend_shifts_list.dart';
import '../widgets/suspend_shifts_selector.dart';

/// Suspensión de fechas de turnos (RF-14, CU 3.3.6): el funcionario busca las
/// fechas de un médico y una especialidad en un rango, elige cuáles suspender,
/// ve qué se afecta y confirma. Solo muestra el estado de
/// `suspendShiftsControllerProvider`; las reglas son del controller.
class SuspendShiftsScreen extends ConsumerWidget {
  const SuspendShiftsScreen({super.key});

  Future<void> _openDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SuspendConfirmDialog(),
    );
    // Si se cerró por afuera (Esc, atrás), no queda una vista previa abierta
    // sin diálogo.
    if (!context.mounted) return;
    if (ref.read(suspendShiftsControllerProvider).preview != null) {
      ref.read(suspendShiftsControllerProvider.notifier).dismissPreview();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      suspendShiftsControllerProvider.select((s) => s.preview != null),
      (wasOpen, isOpen) {
        if (isOpen && wasOpen != true) _openDialog(context, ref);
      },
    );
    ref.listen(suspendShiftsControllerProvider.select((s) => s.result), (
      previous,
      result,
    ) {
      if (result == null || result == previous) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Fechas suspendidas: ${result.shifts.length}. '
            'Consultas canceladas: ${result.cancelledAppointments}.',
          ),
        ),
      );
    });

    final state = ref.watch(suspendShiftsControllerProvider);
    final controller = ref.read(suspendShiftsControllerProvider.notifier);
    final canPreview =
        state.filter != null &&
        state.selectedIds.isNotEmpty &&
        state.phase == SuspendPhase.idle;
    return Scaffold(
      appBar: AppBar(title: const Text('Suspender fechas')),
      body: CenteredContent(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SuspendShiftsSelector(),
            // Con el diálogo abierto, el error se ve ahí y no acá.
            if (state.error != null && state.preview == null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                key: const Key('suspension-screen-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            const SuspendShiftsList(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          // Una fila y no un `Align`: el `Align` se expande a todo el alto que
          // le dan y la barra taparía el cuerpo entero.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                key: const Key('preview-suspension'),
                onPressed: canPreview ? controller.requestPreview : null,
                child: state.phase == SuspendPhase.previewing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Previsualizar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
