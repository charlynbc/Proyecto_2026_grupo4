import 'package:flutter/material.dart';

import '../../../turnos/models/weekday_names.dart';
import '../models/shift_utilization.dart';

/// Ancho disponible desde el que los turnos se muestran como tabla; con menos,
/// cada turno es una tarjeta. Las columnas de la tabla se reparten el ancho y
/// los textos largos pasan a otra línea entre palabras, así que no hace falta
/// desplazarla.
const double kShiftStatsTableMinWidth = 720;

String _clinicText(ShiftUtilizationItem item) =>
    '${item.clinic.name} (${item.clinic.location})';

String _numbersText(ShiftUtilizationItem item) =>
    '${item.occupied} de ${item.offered} números';

/// Los turnos con su utilización: tabla en pantalla ancha, tarjetas en
/// angosta. Las filas van en el orden en que llegan.
class ShiftUtilizationResults extends StatelessWidget {
  const ShiftUtilizationResults({super.key, required this.items});

  final List<ShiftUtilizationItem> items;

  @override
  Widget build(BuildContext context) {
    // Se decide con el ancho que hay de verdad en este lugar, no con el de la
    // ventana.
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= kShiftStatsTableMinWidth
          ? _Table(items)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) _Card(items[i], i),
              ],
            ),
    );
  }
}

/// El texto de utilización tal cual lo manda el servidor y, solo si hay
/// porcentaje, una barra con ese valor. Con "Sin datos" no hay barra.
class _UtilizationCell extends StatelessWidget {
  const _UtilizationCell(this.item, this.index);

  final ShiftUtilizationItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final percentage = item.percentage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(item.utilization),
        if (percentage != null) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            key: Key('stats-shift-bar-$index'),
            value: (percentage / 100).clamp(0.0, 1.0),
          ),
        ],
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table(this.items);

  final List<ShiftUtilizationItem> items;

  static const _flexes = [3, 3, 4, 2, 3, 4];
  static const _headers = [
    'Médico',
    'Especialidad',
    'Consultorio',
    'Día',
    'Números',
    'Utilización',
  ];

  Widget _row(List<Widget> cells, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++)
          Expanded(
            flex: _flexes[i],
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: cells[i],
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return Column(
      key: const Key('stats-shift-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row([for (final h in _headers) Text(h, style: labelStyle)]),
        const Divider(height: 1),
        for (var i = 0; i < items.length; i++) ...[
          _row(key: Key('stats-shift-row-$i'), [
            Text(items[i].doctor.fullName),
            Text(items[i].specialty.name),
            Text(_clinicText(items[i])),
            Text(weekdayLabel(items[i].weekday)),
            Text(_numbersText(items[i])),
            _UtilizationCell(items[i], i),
          ]),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.item, this.index);

  final ShiftUtilizationItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('stats-shift-card-$index'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.doctor.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(item.specialty.name),
            Text(_clinicText(item)),
            Text(weekdayLabel(item.weekday)),
            Text(_numbersText(item)),
            const SizedBox(height: 8),
            _UtilizationCell(item, index),
          ],
        ),
      ),
    );
  }
}
