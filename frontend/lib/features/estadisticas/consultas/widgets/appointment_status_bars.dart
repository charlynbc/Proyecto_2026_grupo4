import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/appointment_statistics.dart';

/// Una fila por estado de consulta, en el orden fijo de la pantalla, con una
/// barra horizontal y la cantidad en texto.
///
/// La escala es común: la barra del estado con más consultas ocupa toda la
/// pista y las demás son proporcionales a ella, así que se pueden comparar
/// entre filas. Un estado sin consultas no dibuja barra; con todos en cero
/// siguen las siete filas, sin barras. Cada fila lleva su nombre arriba y su
/// cantidad al final, así que el color no es lo único que informa.
///
/// Se dibuja con widgets, como los gráficos de Inasistencias y de Pases, para
/// que crezca con el texto: los nombres largos bajan de renglón y no hay
/// desplazamiento horizontal. Reemplaza al gráfico de barras con `fl_chart` y
/// a la lista que repetía sus datos.
class AppointmentStatusBars extends StatelessWidget {
  const AppointmentStatusBars({super.key, required this.statistics});

  final AppointmentStatistics statistics;

  /// El texto que lee el lector de pantalla: "Agendada, 40 consultas". Solo
  /// con exactamente 1 va en singular.
  static String semanticLabel(String key, int count) =>
      '${statisticsStatusLabel(key)}, $count '
      '${count == 1 ? 'consulta' : 'consultas'}';

  /// El ancho de la cantidad más ancha. Todas las filas reservan el mismo, para
  /// que las pistas midan lo mismo y la escala sea la misma en cada una.
  static double _valueWidth(
    List<int> counts,
    TextStyle? style,
    TextScaler textScaler,
  ) {
    var widest = 0.0;
    for (final count in counts) {
      final painter = TextPainter(
        text: TextSpan(text: '$count', style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    final keys = kStatisticsStatusOrder;
    final counts = [for (final key in keys) statistics.counts[key]!];
    final maxCount = counts.fold<int>(0, math.max);
    final valueWidth = _valueWidth(
      counts,
      style,
      MediaQuery.textScalerOf(context),
    );
    return Column(
      key: const Key('stats-status-chart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Consultas por estado',
          key: const Key('stats-status-chart-title'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < keys.length; i++)
          // Un solo texto por fila para el lector de pantalla: lo que se ve
          // queda excluido para que no se lea dos veces.
          Semantics(
            key: Key('stats-state-row-$i'),
            container: true,
            label: semanticLabel(keys[i], counts[i]),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(statisticsStatusLabel(keys[i]), style: style),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _Bar(
                            index: i,
                            fraction: maxCount == 0 ? 0 : counts[i] / maxCount,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: valueWidth,
                          child: Text(
                            '${counts[i]}',
                            key: Key('stats-state-count-$i'),
                            textAlign: TextAlign.end,
                            style: style,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// La pista de fondo y, encima, la barra que ocupa [fraction] de su ancho. Con
/// [fraction] en cero no se dibuja barra.
class _Bar extends StatelessWidget {
  const _Bar({required this.index, required this.fraction});

  final int index;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(4));
    return DecoratedBox(
      key: Key('stats-state-track-$index'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: SizedBox(
        height: 16,
        child: fraction <= 0
            ? null
            : Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fraction.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    key: Key('stats-state-fill-$index'),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
