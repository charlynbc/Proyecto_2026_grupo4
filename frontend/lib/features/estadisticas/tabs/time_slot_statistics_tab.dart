import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../time_slots/models/time_slot_statistics.dart';
import '../time_slots/providers/time_slot_statistics_provider.dart';
import '../time_slots/repositories/time_slot_statistics_repository.dart';
import '../widgets/period_filter.dart';
import '../widgets/period_label.dart';
import '../widgets/stats_palette.dart';

class TimeSlotStatisticsTab extends ConsumerStatefulWidget {
  const TimeSlotStatisticsTab({super.key});
  @override
  ConsumerState<TimeSlotStatisticsTab> createState() =>
      _TimeSlotStatisticsTabState();
}

class _TimeSlotStatisticsTabState extends ConsumerState<TimeSlotStatisticsTab> {
  final fromController = TextEditingController();
  final toController = TextEditingController();
  DateTime? from, to, requestedFrom, requestedTo;
  int? specialtyId;
  TimeSlotView view = TimeSlotView.consultations;
  TimeSlotStatistics? result;
  String? error, periodError;
  bool loading = true;
  int request = 0;
  @override
  void initState() {
    super.initState();
    fetch(null, null);
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  Future<void> fetch(DateTime? start, DateTime? end) async {
    requestedFrom = start;
    requestedTo = end;
    final id = ++request;
    final selectedSpecialty = specialtyId;
    final selectedView = view;
    if (!loading || error != null) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final repo = await ref.read(timeSlotStatisticsRepositoryProvider.future);
      final data = await repo.statistics(
        from: start,
        to: end,
        specialtyId: selectedSpecialty,
        view: selectedView,
      );
      if (!mounted || id != request) return;
      fromController.text = formatUiDate(data.from);
      toController.text = formatUiDate(data.to);
      setState(() {
        result = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted || id != request) return;
      setState(() {
        error = apiMessageOf(e);
        loading = false;
      });
    }
  }

  void consult() {
    if (from != null && to != null && from!.isAfter(to!)) {
      setState(
        () => periodError =
            'La fecha Desde no puede ser posterior a la fecha Hasta.',
      );
      return;
    }
    setState(() => periodError = null);
    fetch(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final specialties = ref.watch(specialtiesProvider);
    return CenteredContent(
      maxWidth: 720,
      // Arriba: el formulario no se mueve cuando cambian los resultados.
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Vista'),
          Wrap(
            spacing: 8,
            children: [
              for (final option in TimeSlotView.values)
                ChoiceChip(
                  label: Text(
                    option == TimeSlotView.consultations
                        ? 'Consultas'
                        : 'Llegadas',
                  ),
                  selected: option == view,
                  onSelected: loading
                      ? null
                      : (selected) {
                          if (selected && option != view) {
                            setState(() => view = option);
                            fetch(from, to);
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 16),
          specialties.when(
            loading: () => const Text('Cargando especialidades'),
            error: (_, _) => Column(
              children: [
                const Text('No se pudieron cargar las especialidades.'),
                TextButton(
                  onPressed: () => ref.invalidate(specialtiesProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
            data: (items) => DropdownButtonFormField<int>(
              initialValue: specialtyId,
              decoration: const InputDecoration(labelText: 'Especialidad'),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('Todas')),
                for (final item in items)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() => specialtyId = value);
                      fetch(from, to);
                    },
            ),
          ),
          const SizedBox(height: 16),
          PeriodFilter(
            fromController: fromController,
            toController: toController,
            onFromChanged: (value) => from = value,
            onToChanged: (value) => to = value,
            onConsult: loading ? null : consult,
            errorText: periodError,
          ),
          const SizedBox(height: 24),
          if (loading)
            const Text('Calculando estadísticas', key: Key('stats-loading'))
          else if (error != null)
            Column(
              children: [
                Text(error!, key: const Key('stats-error')),
                TextButton(
                  onPressed: () => fetch(requestedFrom, requestedTo),
                  child: const Text('Reintentar'),
                ),
              ],
            )
          else if (result case final data?) ...[
            PeriodLabel(from: data.from, to: data.to),
            const SizedBox(height: 12),
            if (!data.cells.any((cell) => cell.count > 0))
              Text(
                view == TimeSlotView.consultations
                    ? 'No hay consultas en el período elegido.'
                    : 'No hay llegadas en el período elegido.',
                key: const Key('stats-empty'),
              )
            else
              _Heatmap(cells: data.cells),
          ],
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.cells});
  final List<TimeSlotCell> cells;
  static const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _dayWidth = 58.0;
  static const _cellWidth = 56.0;
  static const _labelGap = 8.0;

  /// El rango de la escala (0 a 4) de una cantidad mayor que cero: se parte
  /// el máximo en cinco partes iguales y la cantidad cae en la primera cuyo
  /// tope la alcanza. Con enteros para que el borde no dependa de decimales.
  static int rangeOf(int count, int maxCount) =>
      (((count * 5 + maxCount - 1) ~/ maxCount) - 1).clamp(0, 4);

  static String _hourLabel(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00–${(hour + 1).toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <(int, int), int>{};
    for (final cell in cells) {
      counts[(cell.day, cell.hour)] = cell.count;
    }
    final maxCount = cells.fold<int>(
      0,
      (max, c) => c.count > max ? c.count : max,
    );
    // Solo se muestran las horas desde la primera hasta la última con
    // actividad (sumando los siete días); las vacías del medio se conservan.
    final active = [
      for (var hour = 0; hour < 24; hour++)
        if (cells.any((c) => c.hour == hour && c.count > 0)) hour,
    ];
    final firstHour = active.first;
    final lastHour = active.last;
    final hidesHours = firstHour > 0 || lastHour < 23;

    // La etiqueta de hora y la celda se miden con el tamaño de texto del
    // usuario: la etiqueta entra siempre en una línea y la celda alcanza para
    // su número.
    final textStyle = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, {required bool height}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final size = height ? painter.height : painter.width;
      painter.dispose();
      return size;
    }

    var labelWidth = 0.0;
    for (var hour = firstHour; hour <= lastHour; hour++) {
      final width = measure(_hourLabel(hour), height: false);
      if (width > labelWidth) labelWidth = width;
    }
    labelWidth += _labelGap;
    final cellHeight = math.max(32.0, measure('0', height: true) + 8);
    final gridWidth = labelWidth + days.length * _dayWidth;

    final helpStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // El aviso va solo si la grilla no entra en el ancho disponible.
        final overflows = gridWidth > constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cantidad por día y hora (hora de Uruguay)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Column(
              key: const Key('timeslot-help'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hidesHours) ...[
                  Text(
                    'Se ocultan las horas sin actividad al principio y al final',
                    style: helpStyle,
                  ),
                  const SizedBox(height: 4),
                ],
                _Legend(style: helpStyle),
                if (overflows) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Deslizá horizontalmente para ver todos los días',
                    style: helpStyle,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(width: labelWidth),
                      for (final day in days)
                        SizedBox(
                          width: _dayWidth,
                          child: Center(child: Text(day)),
                        ),
                    ],
                  ),
                  for (var hour = firstHour; hour <= lastHour; hour++)
                    Row(
                      children: [
                        SizedBox(
                          width: labelWidth,
                          child: Text(
                            _hourLabel(hour),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                        for (var day = 1; day <= 7; day++)
                          _cell(
                            counts[(day, hour)],
                            day,
                            hour,
                            maxCount,
                            cellHeight,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cell(int? count, int day, int hour, int maxCount, double height) {
    final shade = count == null || count == 0 || maxCount == 0
        ? timeSlotZeroShade
        : timeSlotScale[rangeOf(count, maxCount)];
    return Semantics(
      label: '${days[day - 1]} $hour:00, ${count?.toString() ?? "sin datos"}',
      child: Container(
        width: _cellWidth,
        height: height,
        margin: const EdgeInsets.all(1),
        color: shade.fill,
        child: Center(
          child: Text(
            count?.toString() ?? '–',
            style: TextStyle(color: shade.text),
          ),
        ),
      ),
    );
  }
}

/// La escala de color de menor a mayor cantidad, con el gris de las celdas en
/// cero aparte.
class _Legend extends StatelessWidget {
  const _Legend({required this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).colorScheme.outlineVariant;
    Widget swatch(Key key, Color color) => SizedBox.square(
      key: key,
      dimension: 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: border),
        ),
      ),
    );
    return Wrap(
      key: const Key('timeslot-legend'),
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(const Key('timeslot-legend-zero'), timeSlotZeroShade.fill),
            const SizedBox(width: 4),
            Text('Cero', style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Menos', style: style),
            const SizedBox(width: 4),
            for (var i = 0; i < timeSlotScale.length; i++)
              swatch(Key('timeslot-legend-$i'), timeSlotScale[i].fill),
            const SizedBox(width: 4),
            Text('Más', style: style),
          ],
        ),
      ],
    );
  }
}
