import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../widgets/shifts_filter_bar.dart';
import '../widgets/shifts_results.dart';
import 'shift_routes.dart';

/// Consulta de turnos del funcionario (RF-17, CU 3.3.5) y acceso al alta de
/// un turno semanal.
class ShiftsScreen extends StatelessWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
