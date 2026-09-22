import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/providers/session_provider.dart';

// Datos de ejemplo hardcodeados: todavía no hay endpoint de estadísticas en
// el backend. Esta pantalla es una prueba de concepto de fl_chart.
const _reservasPorProfesional = {
  'Dra. Pérez': 22,
  'Dr. Gómez': 30,
  'Dra. Rodríguez': 14,
  'Dr. Fernández': 8,
};

const _reservasPorDia = [5, 8, 6, 10, 7, 4, 9];

const _reservasActivas = 35.0;
const _reservasCanceladas = 10.0;

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No se usa la flecha automática: si se entra por URL directa no hay nada
    // para hacer pop y la pantalla queda sin salida.
    final isAuthenticated = ref.watch(sessionProvider).isAuthenticated;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(isAuthenticated ? '/home' : '/login'),
        ),
        title: const Text('Estadísticas (demo)'),
      ),
      body: CenteredContent(
        maxWidth: 900,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SampleDataBanner(),
            const SizedBox(height: 24),
            const _ChartCard(
              title: 'Reservas por profesional',
              chart: _ProfessionalsBarChart(),
            ),
            const SizedBox(height: 24),
            const _ChartCard(
              title: 'Reservas por día (últimos 7 días)',
              chart: _DailyLineChart(),
            ),
            const SizedBox(height: 24),
            const _ChartCard(
              title: 'Activas vs. canceladas',
              chart: _StatusPieChart(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleDataBanner extends StatelessWidget {
  const _SampleDataBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Los datos de estos gráficos son de ejemplo y no representan '
              'reservas reales. Es una demostración técnica de gráficos.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.chart});

  final String title;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(height: 280, child: chart),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalsBarChart extends StatelessWidget {
  const _ProfessionalsBarChart();

  @override
  Widget build(BuildContext context) {
    final professionals = _reservasPorProfesional.keys.toList();
    final colorScheme = Theme.of(context).colorScheme;
    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${professionals[group.x]}\n${rod.toY.round()}',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= professionals.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    professionals[index],
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (final entry in _reservasPorProfesional.entries)
            BarChartGroupData(
              x: professionals.indexOf(entry.key),
              barRods: [
                BarChartRodData(
                  toY: entry.value.toDouble(),
                  color: colorScheme.primary,
                  width: 22,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DailyLineChart extends StatelessWidget {
  const _DailyLineChart();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => colorScheme.inverseSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                return LineTooltipItem(
                  touchedSpot.y.round().toString(),
                  TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _reservasPorDia.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    'Día ${index + 1}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.15),
            ),
            spots: [
              for (var i = 0; i < _reservasPorDia.length; i++)
                FlSpot(i.toDouble(), _reservasPorDia[i].toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  const _StatusPieChart();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = _reservasActivas + _reservasCanceladas;
    final activasPct = (_reservasActivas / total * 100).round();
    final canceladasPct = 100 - activasPct;
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  value: _reservasActivas,
                  color: colorScheme.primary,
                  title: '$activasPct%',
                  radius: 80,
                  titleStyle: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PieChartSectionData(
                  value: _reservasCanceladas,
                  color: colorScheme.error,
                  title: '$canceladasPct%',
                  radius: 80,
                  titleStyle: TextStyle(
                    color: colorScheme.onError,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Indicator(color: colorScheme.primary, label: 'Activas'),
            const SizedBox(width: 24),
            _Indicator(color: colorScheme.error, label: 'Canceladas'),
          ],
        ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
