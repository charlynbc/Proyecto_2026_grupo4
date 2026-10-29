import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../providers/schedules_page_provider.dart';
import '../providers/schedules_refresh_provider.dart';
import '../repositories/schedule_repository.dart';
import '../widgets/schedule_filter_bar.dart';
import '../widgets/schedule_results.dart';

/// Lo que se muestra ante cualquier error que no sea de validación.
const String _loadErrorMessage =
    'No pudimos cargar las consultas. Intentá de nuevo.';

/// Consulta de agendas del funcionario (RF-18, CU 3.3.6): las consultas de un
/// día con sus filtros, que se actualiza sola cada 15 segundos mientras la
/// pantalla está a la vista.
class SchedulesScreen extends ConsumerWidget {
  const SchedulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantiene vivo el refresco mientras la pantalla está montada.
    ref.watch(schedulesRefreshProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendas'),
        actions: const [LogoutButton()],
      ),
      body: const CenteredContent(
        maxWidth: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [ScheduleFilterBar(), SizedBox(height: 16), _Results()],
        ),
      ),
    );
  }
}

/// El resultado de la última consulta: spinner solo mientras no hay datos,
/// la lista (aunque se esté recargando) y, si falló, el aviso con
/// "Reintentar".
class _Results extends ConsumerWidget {
  const _Results();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(schedulesPageProvider);
    final error = page.hasError ? page.error : null;
    final data = page.hasValue ? page.value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // El aviso no depende de que se esté recargando: así el refresco no
        // lo cambia por el spinner en cada vuelta.
        if (error != null) _ErrorNotice(error),
        if (data != null)
          ScheduleResults(page: data)
        else if (error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _ErrorNotice extends ConsumerWidget {
  const _ErrorNotice(this.error);

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = error is ScheduleValidationException
        ? (error as ScheduleValidationException).message
        : _loadErrorMessage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(schedulesPageProvider),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
