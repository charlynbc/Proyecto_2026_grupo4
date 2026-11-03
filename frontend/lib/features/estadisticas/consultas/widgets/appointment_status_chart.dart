import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/appointment_statistics.dart';

/// Una barra por estado, en el orden fijo de la pantalla. Si no entran en el
/// ancho disponible, el gráfico se desplaza en horizontal y lo avisa con una
/// barra siempre visible y un texto de ayuda.
///
/// Con total cero las siete barras siguen, todas en cero.
class AppointmentStatusChart extends StatefulWidget {
  const AppointmentStatusChart({super.key, required this.statistics});

  final AppointmentStatistics statistics;

  @override
  State<AppointmentStatusChart> createState() => _AppointmentStatusChartState();
}

class _AppointmentStatusChartState extends State<AppointmentStatusChart> {
  static const double _minSlotWidth = 72;
  static const double _slotPadding = 8;
  static const double _height = 260;

  /// Aire arriba, para que la etiqueta más alta del eje Y no se recorte, y
  /// abajo, para que la barra de desplazamiento no tape los nombres.
  static const double _verticalPadding = 12;

  /// Espacio entre las barras y el nombre (el de `SideTitleWidget`) más un
  /// poco de aire.
  static const double _axisGap = 12;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  TextPainter _painter(
    String text,
    TextStyle? style,
    TextScaler textScaler,
    double maxWidth,
  ) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);

  /// El ancho de la palabra más larga de las etiquetas. La ranura de cada
  /// barra tiene que alcanzar para ella: si no, el texto se parte a mitad de
  /// palabra. Los espacios sí pueden cortar la línea.
  double _longestWordWidth(
    List<String> labels,
    TextStyle? style,
    TextScaler textScaler,
  ) {
    var widest = 0.0;
    for (final label in labels) {
      for (final word in label.split(' ')) {
        final painter = _painter(word, style, textScaler, double.infinity);
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
    }
    return widest;
  }

  /// El alto de la etiqueta que ocupa más renglones, con el ancho que va a
  /// tener. El eje reserva ese alto: así ninguna se recorta.
  double _tallestLabelHeight(
    List<String> labels,
    TextStyle? style,
    TextScaler textScaler,
    double width,
  ) {
    var tallest = 0.0;
    for (final label in labels) {
      final painter = _painter(label, style, textScaler, width);
      tallest = math.max(tallest, painter.height);
      painter.dispose();
    }
    return tallest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall;
    final textScaler = MediaQuery.textScalerOf(context);
    final keys = kStatisticsStatusOrder;
    final labels = [for (final key in keys) statisticsStatusLabel(key)];
    final counts = [for (final key in keys) widget.statistics.counts[key]!];

    final slotWidth = math.max(
      _minSlotWidth,
      _longestWordWidth(labels, labelStyle, textScaler).ceil() + _slotPadding,
    );
    final labelWidth = slotWidth - _slotPadding;
    final axisHeight =
        _tallestLabelHeight(
          labels,
          labelStyle,
          textScaler,
          labelWidth,
        ).ceilToDouble() +
        _axisGap;
    final maxCount = counts.fold<int>(0, math.max);

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
                      child: Text(value.toInt().toString(), style: labelStyle),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: axisHeight,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: SizedBox(
                    width: labelWidth,
                    child: Text(
                      labels[index],
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
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  '${labels[groupIndex]}\n${counts[groupIndex]}',
                  TextStyle(color: theme.colorScheme.onInverseSurface),
                ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < counts.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: counts[i].toDouble(),
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
        final needed = labels.length * slotWidth + 36;
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
                  'Deslizá hacia los costados para ver todos los estados',
                  key: const Key('stats-chart-scroll-hint'),
                  textAlign: TextAlign.center,
                  style: labelStyle?.copyWith(
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
