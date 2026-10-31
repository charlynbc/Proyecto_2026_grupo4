import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/specialty_demand.dart';

/// Una barra por especialidad, en el orden en que llegan.
class SpecialtyDemandChart extends StatelessWidget {
  const SpecialtyDemandChart({super.key, required this.items});

  final List<SpecialtyDemandItem> items;

  static const double _barSlotWidth = 72;
  static const double _height = 240;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    width: _barSlotWidth - 8,
                    child: Text(
                      items[index].specialty.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall,
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
        final needed = items.length * _barSlotWidth + 36;
        final width = math.max(constraints.maxWidth, needed);
        return SizedBox(
          height: _height,
          child: width > constraints.maxWidth
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: width, child: chart),
                )
              : chart,
        );
      },
    );
  }
}
