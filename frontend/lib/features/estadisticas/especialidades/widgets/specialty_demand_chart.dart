import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/specialty_demand.dart';

/// Una barra por especialidad, en el orden en que llegan. Si no entran en el
/// ancho disponible, el gráfico se desplaza en horizontal y lo avisa con una
/// barra siempre visible y un texto de ayuda.
class SpecialtyDemandChart extends StatefulWidget {
  const SpecialtyDemandChart({super.key, required this.items});

  final List<SpecialtyDemandItem> items;

  @override
  State<SpecialtyDemandChart> createState() => _SpecialtyDemandChartState();
}

class _SpecialtyDemandChartState extends State<SpecialtyDemandChart> {
  static const double _minSlotWidth = 72;
  static const double _slotPadding = 8;
  static const double _height = 240;

  /// Aire arriba, para que la etiqueta más alta del eje Y no se recorte, y
  /// abajo, para que la barra de desplazamiento no tape los nombres.
  static const double _verticalPadding = 12;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// El ancho de la palabra más larga de los nombres con [style]. La ranura
  /// de cada barra tiene que alcanzar para ella: si no, el texto se parte a
  /// mitad de palabra. Los espacios sí pueden cortar la línea.
  double _longestWordWidth(TextStyle? style, TextScaler textScaler) {
    var widest = 0.0;
    for (final item in widget.items) {
      for (final word in item.specialty.name.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall;
    final slotWidth = math.max(
      _minSlotWidth,
      _longestWordWidth(labelStyle, MediaQuery.textScalerOf(context)).ceil() +
          _slotPadding,
    );
    final maxCount = items.fold<int>(
      0,
      (max, item) => math.max(max, item.count),
    );
    final chart = BarChart(
      BarChartData(
        minY: 0,
        // Con todas las cantidades en 0 el eje no puede quedar sin alto.
        maxY: math.max(maxCount, 1) * 1.2,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => value == value.roundToDouble()
                  ? SideTitleWidget(
                      meta: meta,
                      child: Text(
                        value.toInt().toString(),
                        style: theme.textTheme.labelSmall,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= items.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: SizedBox(
                    width: slotWidth - _slotPadding,
                    child: Text(
                      items[index].specialty.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: labelStyle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = items[groupIndex];
              return BarTooltipItem(
                '${item.specialty.name}\n${item.count}',
                TextStyle(color: theme.colorScheme.onInverseSurface),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: items[i].count.toDouble(),
                  width: 24,
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = items.length * slotWidth + 36;
        final width = math.max(constraints.maxWidth, needed);
        final scrolls = width > constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _height,
              child: scrolls
                  ? Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          vertical: _verticalPadding,
                        ),
                        child: SizedBox(width: width, child: chart),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: _verticalPadding),
                      child: chart,
                    ),
            ),
            if (scrolls)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Deslizá hacia los costados para ver todas las '
                  'especialidades',
                  key: const Key('stats-chart-scroll-hint'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
