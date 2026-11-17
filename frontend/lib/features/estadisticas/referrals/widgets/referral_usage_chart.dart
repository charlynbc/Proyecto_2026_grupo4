import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/stats_palette.dart';
import '../models/referral_statistics.dart';

/// Los tres tramos de una barra, en el orden en que se apilan.
enum _Part {
  used('used', 'Utilizados', 'utilizado', 'utilizados', referralUsedShade),
  available(
    'available',
    'Disponibles',
    'disponible',
    'disponibles',
    referralAvailableShade,
  ),
  expired('expired', 'Vencidos', 'vencido', 'vencidos', referralExpiredShade);

  const _Part(this.key, this.legend, this.singular, this.plural, this.shade);

  /// El sufijo de las claves de prueba de cada tramo.
  final String key;
  final String legend;
  final String singular;
  final String plural;

  /// Relleno, borde y color del número del tramo.
  final StatsShade shade;

  int countOf(ReferralItem item) => switch (this) {
    _Part.used => item.used,
    _Part.available => item.available,
    _Part.expired => item.expired,
  };

  String countText(int count) => '$count ${count == 1 ? singular : plural}';
}

/// Una barra apilada por especialidad de destino con los pases utilizados,
/// disponibles y vencidos, en el orden en que llegan las especialidades.
///
/// La escala es común: la barra de la especialidad con más pases (la suma de
/// los tres tramos, no `emitidos`) ocupa todo el ancho y las demás son
/// proporcionales a ella. Cada tramo es un color sólido con un borde fino
/// (utilizados oscuro, disponibles medio y vencidos claro, así que también se
/// distinguen en escala de grises) y lleva su número en texto, así que el
/// color no es lo único que informa. Si un tramo es demasiado angosto para su número, el número
/// sale debajo de la barra. Una especialidad sin pases se muestra sin barra.
/// Se dibuja con widgets, como el gráfico de Inasistencias, para que crezca
/// con el texto.
///
/// Es la única vista de la pestaña: cada fila lleva, además de la barra, los
/// cinco datos de la especialidad (emitidos, utilizados, disponibles,
/// vencidos y utilización) en una línea que baja de renglón si no entra. Con
/// pases en ninguna especialidad se muestran igual las filas, sin barra. Sin
/// especialidades no dibuja nada.
class ReferralUsageChart extends StatelessWidget {
  const ReferralUsageChart({super.key, required this.items});

  /// Todas las especialidades de la respuesta, en el orden en que llegan. Se
  /// muestran las que indica [visible].
  final List<ReferralItem> items;

  static int _total(ReferralItem item) =>
      item.used + item.available + item.expired;

  /// Las filas que se muestran. Decisión de producto: una especialidad de pase
  /// libre (que no exige pase) solo se ve si tiene pases emitidos, para que no
  /// llenen la pantalla las que no tienen nada para mostrar; si tiene alguno,
  /// se ve para no ocultar datos reales. Las que exigen pase se ven siempre,
  /// aunque estén en cero. Las filas, los totales y la escala común se calculan
  /// solo con las visibles.
  static List<ReferralItem> visible(List<ReferralItem> items) => [
    for (final item in items)
      if (item.requiresReferral || item.issued > 0) item,
  ];

  static String _issuedText(int count) =>
      '$count ${count == 1 ? 'emitido' : 'emitidos'}';

  /// El texto que lee el lector de pantalla: todo lo de la línea de datos. La
  /// utilización se lee con coma decimal ("71,43 %").
  static String semanticLabel(ReferralItem item) {
    final noPasses = _total(item) == 0 ? 'sin pases, ' : '';
    return '${item.name}, $noPasses${_issuedText(item.issued)}, '
        '${_Part.used.countText(item.used)}, '
        '${_Part.available.countText(item.available)}, '
        '${_Part.expired.countText(item.expired)}, '
        'utilización ${item.utilization.replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = visible(items);
    final maxTotal = rows.fold<int>(
      0,
      (max, item) => math.max(max, _total(item)),
    );
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      key: const Key('referral-chart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pases por especialidad de destino',
          key: const Key('referral-chart-title'),
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        // Sin barras no hay nada que explicar con la leyenda.
        if (maxTotal > 0) ...[
          Wrap(
            key: const Key('referral-chart-legend'),
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final part in _Part.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Swatch(
                      part: part,
                      size: 16,
                      key: Key('referral-legend-${part.key}'),
                    ),
                    const SizedBox(width: 6),
                    Text(part.legend, style: theme.textTheme.bodySmall),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < rows.length; i++)
          // Un solo texto por fila para el lector de pantalla: lo que se ve
          // queda excluido para que no se lea dos veces.
          Semantics(
            key: Key('referral-row-$i'),
            container: true,
            label: semanticLabel(rows[i]),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(rows[i].name, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    if (_total(rows[i]) == 0)
                      Align(
                        key: Key('referral-none-$i'),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'sin pases',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      _StackedBar(index: i, item: rows[i], maxTotal: maxTotal),
                    const SizedBox(height: 10),
                    _DataLine(index: i, item: rows[i]),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Los cinco datos de una especialidad, cada uno entero: si no entran en un
/// renglón, el que sobra baja al siguiente.
class _DataLine extends StatelessWidget {
  const _DataLine({required this.index, required this.item});

  final int index;
  final ReferralItem item;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      key: Key('referral-data-$index'),
      spacing: 12,
      runSpacing: 4,
      children: [
        Text('Emitidos: ${item.issued}', style: style),
        Text('Utilizados: ${item.used}', style: style),
        Text('Disponibles: ${item.available}', style: style),
        Text('Vencidos: ${item.expired}', style: style),
        Text('Utilización: ${item.utilization}', style: style),
      ],
    );
  }
}

/// La pista con los tramos de una especialidad y, debajo, los números de los
/// tramos que no entran en la barra.
class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.index,
    required this.item,
    required this.maxTotal,
  });

  final int index;
  final ReferralItem item;
  final int maxTotal;

  static const _badgePadding = 4.0;
  static const _badgeMargin = 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final segments = <(_Part, int, double, bool)>[];
        var barHeight = 22.0;
        for (final part in _Part.values) {
          final count = part.countOf(item);
          if (count == 0) continue;
          final painter = TextPainter(
            text: TextSpan(text: '$count', style: style),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout();
          final badgeWidth = painter.width + 2 * _badgePadding;
          barHeight = math.max(barHeight, painter.height + 6);
          painter.dispose();
          final segmentWidth = count / maxTotal * width;
          segments.add((
            part,
            count,
            segmentWidth,
            segmentWidth >= badgeWidth + 2 * _badgeMargin,
          ));
        }
        final outside = [
          for (final s in segments)
            if (!s.$4) s,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: DecoratedBox(
                key: Key('referral-track-$index'),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: SizedBox(
                  height: barHeight,
                  child: Row(
                    children: [
                      for (final (part, count, segmentWidth, fits) in segments)
                        SizedBox(
                          key: Key('referral-seg-$index-${part.key}'),
                          width: segmentWidth,
                          height: barHeight,
                          child: DecoratedBox(
                            decoration: _shadeDecoration(part.shade),
                            child: fits
                                ? Center(
                                    child: _CountBadge(
                                      count: count,
                                      color: part.shade.text,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (outside.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  for (final (part, count, _, _) in outside)
                    Row(
                      key: Key('referral-out-$index-${part.key}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Swatch(part: part, size: 12),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(part.countText(count), style: style),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

BoxDecoration _shadeDecoration(StatsShade shade, {double radius = 0}) =>
    BoxDecoration(
      color: shade.fill,
      border: Border.all(color: shade.border!, width: 1),
      borderRadius: radius == 0 ? null : BorderRadius.circular(radius),
    );

/// El número de un tramo, del color de texto que lo hace legible sobre el
/// relleno del tramo.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _StackedBar._badgePadding),
    child: Text(
      '$count',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
    ),
  );
}

/// Un cuadradito con el color de un tramo, para la leyenda y los números
/// que salen de la barra.
class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.part, required this.size});

  final _Part part;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(decoration: _shadeDecoration(part.shade, radius: 2)),
  );
}
