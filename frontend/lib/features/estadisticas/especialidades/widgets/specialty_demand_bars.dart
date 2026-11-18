import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/specialty_demand.dart';

/// Una fila por especialidad, en el orden en que llegan del servidor, con una
/// barra horizontal, la cantidad de consultas en texto y la marca "Requiere
/// pase" cuando corresponde.
///
/// La escala es común: la barra de la especialidad con más consultas ocupa
/// toda la pista y las demás son proporcionales a ella. Una especialidad sin
/// consultas no dibuja barra y dice 0; con todas en cero siguen las filas, sin
/// barras. El nombre se muestra completo (baja de renglón, no se corta con
/// puntos suspensivos) y la cantidad va al final de la fila, así que el color
/// no es lo único que informa.
///
/// Se dibuja con widgets, como los gráficos de Inasistencias y de Pases, para
/// que crezca con el texto: no hay desplazamiento horizontal y con decenas de
/// especialidades la pantalla se desplaza en vertical. Reemplaza al gráfico de
/// barras con `fl_chart` y a la lista que repetía sus datos. Sin
/// especialidades no dibuja nada.
class SpecialtyDemandBars extends StatelessWidget {
  const SpecialtyDemandBars({super.key, required this.items});

  /// Todas las especialidades de la respuesta, en el orden en que llegan.
  final List<SpecialtyDemandItem> items;

  /// El texto que lee el lector de pantalla: "Cardiología, 12 consultas,
  /// requiere pase". Solo con exactamente 1 va en singular, y la parte del
  /// pase solo está si la especialidad lo exige.
  static String semanticLabel(SpecialtyDemandItem item) =>
      '${item.specialty.name}, ${item.count} '
      '${item.count == 1 ? 'consulta' : 'consultas'}'
      '${item.specialty.requiresReferral ? ', requiere pase' : ''}';

  /// El ancho de la cantidad más ancha. Todas las filas reservan el mismo, para
  /// que las pistas midan lo mismo y la escala sea la misma en cada una.
  static double _valueWidth(
    List<SpecialtyDemandItem> items,
    TextStyle? style,
    TextScaler textScaler,
  ) {
    var widest = 0.0;
    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(text: '${item.count}', style: style),
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
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    final maxCount = items.fold<int>(
      0,
      (max, item) => math.max(max, item.count),
    );
    final valueWidth = _valueWidth(
      items,
      style,
      MediaQuery.textScalerOf(context),
    );
    return Column(
      key: const Key('stats-demand-chart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Consultas agendadas por especialidad',
          key: const Key('stats-demand-chart-title'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++)
          // Un solo texto por fila para el lector de pantalla: lo que se ve
          // queda excluido para que no se lea dos veces.
          Semantics(
            key: Key('stats-row-$i'),
            container: true,
            label: semanticLabel(items[i]),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(items[i].specialty.name, style: style),
                    if (items[i].specialty.requiresReferral)
                      Text(
                        'Requiere pase',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _Bar(
                            index: i,
                            fraction: maxCount == 0
                                ? 0
                                : items[i].count / maxCount,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: valueWidth,
                          child: Text(
                            '${items[i].count}',
                            key: Key('stats-demand-count-$i'),
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
      key: Key('stats-demand-track-$index'),
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
                    key: Key('stats-demand-fill-$index'),
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
