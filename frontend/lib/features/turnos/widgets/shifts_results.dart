import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/shift.dart';
import '../../../core/utils/ui_date.dart';
import '../models/shift_number.dart';
import '../models/shift_page.dart';
import '../models/weekday_names.dart';
import '../providers/shift_filters_controller.dart';
import '../providers/shifts_page_provider.dart';
import '../screens/shift_routes.dart';

/// Ancho disponible desde el que los turnos se muestran como tabla; con menos,
/// cada fecha es una tarjeta. La tabla mide 860,1 px con Roboto y los turnos
/// de los datos falsos (`columnSpacing: 24`, `horizontalMargin: 16`); con
/// "Miércoles", el día más ancho, serían 877,7 px (+17,6 px sobre "Martes"). Se
/// suma ~7 % para nombres más largos que los del seed: 877,7 × 1,07 ≈ 939,1,
/// redondeado a 940. La columna "Configuración" suma cerca de 100 px, así que
/// entre 940 y ~1040 puede aparecer el desplazamiento horizontal. Si la tabla
/// igual no entra, queda ese desplazamiento.
const double kShiftsTableMinWidth = 940;

String _schedule(Shift shift) =>
    '${ShiftNumber.formatTime(shift.startMinutes)} – '
    '${ShiftNumber.formatTime(shift.endMinutes)}';

/// La página de turnos: tabla o tarjetas, el aviso de "sin resultados" y el
/// paginador.
class ShiftsResults extends ConsumerWidget {
  const ShiftsResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(shiftsPageProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return page.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No pudimos cargar los turnos. Intentá de nuevo.',
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(shiftsPageProvider),
            child: const Text('Reintentar'),
          ),
        ],
      ),
      data: (data) => data.items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No se encontraron turnos con esos filtros. Cambiá los '
                'criterios y volvé a buscar.',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Se decide con el ancho que hay de verdad en este lugar (la
                // pantalla menos márgenes y menú), no con el de la ventana.
                LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxWidth >= kShiftsTableMinWidth
                      ? _ShiftsTable(data.items)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final shift in data.items) _ShiftCard(shift),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                _Pager(data),
              ],
            ),
    );
  }
}

class _ShiftsTable extends StatefulWidget {
  const _ShiftsTable(this.items);

  final List<Shift> items;

  @override
  State<_ShiftsTable> createState() => _ShiftsTableState();
}

class _ShiftsTableState extends State<_ShiftsTable> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La barra se ve siempre (si la tabla no entra) para que se note que se
    // puede desplazar.
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          horizontalMargin: 16,
          columns: const [
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Médico')),
            DataColumn(label: Text('Especialidad')),
            DataColumn(label: Text('Día')),
            DataColumn(label: Text('Horario')),
            DataColumn(label: Text('Consultorio')),
            DataColumn(label: Text('Números')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Configuración')),
          ],
          rows: [
            for (final shift in widget.items)
              DataRow(
                cells: [
                  DataCell(Text(formatUiDate(shift.date))),
                  DataCell(Text(shift.doctor.fullName)),
                  DataCell(Text(shift.specialty.name)),
                  DataCell(Text(weekdayLabel(shift.weekday))),
                  DataCell(Text(_schedule(shift))),
                  DataCell(Text(shift.clinic.name)),
                  DataCell(Text('${shift.numberCount}')),
                  DataCell(Text(shift.state.label)),
                  DataCell(_ConfigLink(shift, label: 'Ver')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard(this.shift);

  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shift.doctor.fullName, style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('${shift.specialty.name} · ${shift.clinic.name}'),
            Text(
              '${weekdayLabel(shift.weekday)} ${formatUiDate(shift.date)} · '
              '${_schedule(shift)}',
            ),
            Text(
              'Números: ${shift.numberCount} · Estado: ${shift.state.label}',
            ),
            _ConfigLink(shift, label: 'Ver configuración'),
          ],
        ),
      ),
    );
  }
}

class _ConfigLink extends StatelessWidget {
  const _ConfigLink(this.shift, {required this.label});

  final Shift shift;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: Key('shift-config-link-${shift.id}'),
      onPressed: () =>
          context.go(weeklyShiftDetailLocation(shift.weeklyShiftId)),
      child: Text(label),
    );
  }
}

class _Pager extends ConsumerWidget {
  const _Pager(this.page);

  final ShiftPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(shiftFiltersControllerProvider.notifier);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        OutlinedButton(
          onPressed: page.hasPrevious
              ? () => controller.goToPage(page.page - 1)
              : null,
          child: const Text('Anterior'),
        ),
        Text(
          'Página ${page.page + 1} de ${page.pageCount} · '
          '${page.total} ${page.total == 1 ? 'turno' : 'turnos'}',
        ),
        OutlinedButton(
          onPressed: page.hasNext
              ? () => controller.goToPage(page.page + 1)
              : null,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }
}
