import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../providers/shifts_page_provider.dart';
import '../widgets/shifts_filter_bar.dart';
import '../widgets/shifts_results.dart';
import 'shift_routes.dart';

/// Consulta de turnos del funcionario (RF-17, CU 3.3.5) y acceso al alta de
/// un turno semanal.
class ShiftsScreen extends StatelessWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ReloadShiftsWhenShown(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Turnos'),
          actions: const [LogoutButton()],
        ),
        body: CenteredContent(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go(kSuspendShiftsPath),
                      icon: const Icon(Icons.event_busy),
                      label: const Text('Suspender fechas'),
                    ),
                    FilledButton(
                      onPressed: () => context.go(kReinstateShiftsPath),
                      child: const Text('Rehabilitar fechas'),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.go(kNewWeeklyShiftPath),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo turno semanal'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const ShiftsFilterBar(),
              const SizedBox(height: 16),
              const ShiftsResults(),
            ],
          ),
        ),
      ),
    );
  }
}

/// La consulta queda armada debajo de rehabilitar. Al volver a quedar
/// adelante, pide la lista de nuevo y muestra el estado actual.
class _ReloadShiftsWhenShown extends ConsumerStatefulWidget {
  const _ReloadShiftsWhenShown({required this.child});

  final Widget child;

  @override
  ConsumerState<_ReloadShiftsWhenShown> createState() =>
      _ReloadShiftsWhenShownState();
}

class _ReloadShiftsWhenShownState
    extends ConsumerState<_ReloadShiftsWhenShown> {
  var _shown = false;
  var _left = false;
  var _reload = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = ModalRoute.of(context)?.isCurrent ?? false;
    if (shown && !_shown && _left) _reload = true;
    if (!shown && _shown) _left = true;
    _shown = shown;
  }

  @override
  Widget build(BuildContext context) {
    if (_reload) {
      _reload = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
        ref.invalidate(shiftsPageProvider);
      });
    }
    return widget.child;
  }
}
