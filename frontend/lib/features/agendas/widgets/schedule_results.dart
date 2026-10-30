import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_date.dart';
import '../models/schedule_entry.dart';
import '../models/schedule_page.dart';
import '../models/schedule_status_label.dart';
import '../providers/schedule_filters_controller.dart';

/// Ancho disponible desde el que las consultas se muestran como tabla; con
/// menos, cada una es una tarjeta. Es el mismo punto de corte que el de la
/// consulta de turnos (`kShiftsTableMinWidth`): la tabla de agendas tiene la
/// misma cantidad de columnas, y si igual no entra queda el desplazamiento
/// horizontal.
const double kSchedulesTableMinWidth = 940;

const String _noArrival = 'Sin aviso';

String _time(ScheduleEntry entry) => '${entry.startTime} - ${entry.endTime}';

String _arrival(ScheduleEntry entry) => entry.arrivalTime ?? _noArrival;

/// La página de la agenda: el total, la tabla o las tarjetas, el aviso de
/// "sin resultados" y el paginador.
class ScheduleResults extends StatelessWidget {
  const ScheduleResults({super.key, required this.page});

  final SchedulePage page;

  @override
  Widget build(BuildContext context) {
    if (page.items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No hay consultas con esos filtros.'),
          ),
          // Sin filas pero con total: el refresco encontró menos que antes y
          // hay que poder volver a una página que exista.
          if (page.total > 0) _Pager(page),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${page.total} ${page.total == 1 ? 'consulta' : 'consultas'}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        // Se decide con el ancho que hay de verdad en este lugar (la pantalla
        // menos márgenes y menú), no con el de la ventana.
        LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= kSchedulesTableMinWidth
              ? _ScheduleTable(page.items)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in page.items) _ScheduleCard(entry),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        _Pager(page),
      ],
    );
  }
}

class _ScheduleTable extends StatefulWidget {
  const _ScheduleTable(this.items);

  final List<ScheduleEntry> items;

  @override
  State<_ScheduleTable> createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<_ScheduleTable> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Dos renglones en una celda: el dato y, abajo y más chico, su detalle.
  Widget _twoLines(BuildContext context, String main, String detail) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(main),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
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
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Consulta')),
            DataColumn(label: Text('Socio')),
            DataColumn(label: Text('Médico')),
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Hora')),
            DataColumn(label: Text('Consultorio')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Llegada')),
          ],
          rows: [
            for (final entry in widget.items)
              DataRow(
                cells: [
                  DataCell(Text('${entry.appointmentId}')),
                  DataCell(
                    _twoLines(
                      context,
                      entry.member.fullName,
                      'CI ${entry.member.ci}',
                    ),
                  ),
                  DataCell(
                    _twoLines(
                      context,
                      entry.doctor.fullName,
                      entry.specialty.name,
                    ),
                  ),
                  DataCell(Text(formatUiDate(entry.date))),
                  DataCell(Text(_time(entry))),
                  DataCell(Text(entry.clinic.name)),
                  DataCell(Text(scheduleStatusLabel(entry.status))),
                  DataCell(Text(_arrival(entry))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard(this.entry);

  final ScheduleEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.member.fullName, style: textTheme.titleMedium),
            Text('CI ${entry.member.ci}'),
            Text('Consulta ${entry.appointmentId}'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                Text(entry.doctor.fullName),
                Text(entry.specialty.name),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                Text(formatUiDate(entry.date)),
                Text(_time(entry)),
                Text(entry.clinic.name),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                Text(scheduleStatusLabel(entry.status)),
                const Text('Llegada:'),
                Text(_arrival(entry)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends ConsumerWidget {
  const _Pager(this.page);

  final SchedulePage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se lee al tocar y no al construir: así no queda en la mano un controller
    // que se descartó entre tanto.
    void goTo(int pageNumber) => ref
        .read(scheduleFiltersControllerProvider.notifier)
        .goToPage(pageNumber);
    // Más allá de la última página (pasa si el refresco encuentra menos
    // consultas) se muestra la última, para no decir "Página 4 de 3".
    final shown = page.page + 1 > page.pageCount
        ? page.pageCount
        : page.page + 1;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        OutlinedButton(
          onPressed: page.hasPrevious ? () => goTo(page.page - 1) : null,
          child: const Text('Anterior'),
        ),
        Text('Página $shown de ${page.pageCount}'),
        OutlinedButton(
          onPressed: page.hasNext ? () => goTo(page.page + 1) : null,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }
}
