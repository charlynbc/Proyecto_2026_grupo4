import 'package:flutter/material.dart';

import '../models/absence_statistics.dart';
import '../repositories/absence_statistics_repository.dart';

/// Barras horizontales con el porcentaje de inasistencia de cada grupo, en el
/// orden en que llegan del servidor.
///
/// La escala es fija, de 0 a 100 %: una barra del 40 % ocupa el 40 % de la
/// pista. Cada fila lleva el nombre arriba, la pista de la barra y el valor en
/// texto al final, así que el color no es lo único que informa. Se dibujan con
/// widgets y no con un paquete de gráficos para que crezcan con el texto.
///
/// Sin grupos no dibuja nada.
class AbsenceRateChart extends StatelessWidget {
  const AbsenceRateChart({
    super.key,
    required this.items,
    required this.grouping,
  });

  final List<AbsenceGroup> items;
  final AbsenceGrouping grouping;

  static String _fullName(AbsenceGroup group) {
    final lastName = group.lastName;
    return lastName == null || lastName.isEmpty
        ? group.name
        : '${group.name} $lastName';
  }

  /// Lo que lee un lector de pantalla: el grupo con más inasistencia, o que
  /// no hay ninguna. Las barras no se anuncian: el detalle está en las
  /// tarjetas de abajo.
  static String _summary(List<AbsenceGroup> items) {
    var highest = items.first;
    for (final group in items) {
      if (group.percentage > highest.percentage) highest = group;
    }
    if (highest.percentage <= 0) return 'Sin inasistencias en el período';
    return 'Mayor inasistencia: ${_fullName(highest)}, '
        '${highest.percentageText}';
  }

  /// El ancho del valor más ancho. Todas las filas reservan el mismo, para que
  /// las pistas midan lo mismo y la escala sea la misma en cada una.
  static double _valueWidth(
    List<AbsenceGroup> items,
    TextStyle? style,
    TextScaler textScaler,
  ) {
    var widest = 0.0;
    for (final text in [
      '100 %',
      for (final group in items) group.percentageText,
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyMedium;
    final valueWidth = _valueWidth(
      items,
      valueStyle,
      MediaQuery.textScalerOf(context),
    );
    final title = switch (grouping) {
      AbsenceGrouping.specialty =>
        'Porcentaje de inasistencia por especialidad',
      AbsenceGrouping.doctor => 'Porcentaje de inasistencia por médico',
    };
    return Column(
      key: const Key('absence-chart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: const Key('absence-chart-title'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          label: _summary(items),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _fullName(items[i]),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _Bar(
                                index: i,
                                fraction: items[i].percentage / 100,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: valueWidth,
                              child: Text(
                                items[i].percentageText,
                                style: valueStyle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// La pista de fondo y, encima, la barra que ocupa [fraction] de su ancho.
class _Bar extends StatelessWidget {
  const _Bar({required this.index, required this.fraction});

  final int index;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(4));
    return DecoratedBox(
      key: Key('absence-bar-track-$index'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: SizedBox(
        height: 16,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              key: Key('absence-bar-fill-$index'),
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
