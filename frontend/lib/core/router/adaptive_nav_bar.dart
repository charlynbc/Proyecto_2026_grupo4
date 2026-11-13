import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Un destino de [AdaptiveNavBar].
class AdaptiveNavDestination {
  const AdaptiveNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barra inferior donde cada destino ocupa el ancho de su rótulo.
///
/// El reparto usa el ancho del texto a 11 px más 2 px por lado, con un piso
/// de 48 px. No depende de cuál destino está elegido, así la barra no salta.
/// El texto del sistema se limita a 1,3, como Material, y si aun así no entra
/// se achica dentro de su ranura sin bajar de unos 11 px.
///
/// La etiqueta para el lector de pantalla es "Pestaña N de M", también en web.
class AdaptiveNavBar extends StatelessWidget {
  const AdaptiveNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AdaptiveNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _labelStyle = TextStyle(
    fontSize: 11,
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w400,
    height: 1.15,
    letterSpacing: 0.25,
  );

  static double _measure(String text, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  /// Una sola línea pesa por el rótulo entero. Con un espacio, por la palabra
  /// más larga, que es la que define las dos líneas.
  static double _contentWidth(String label, TextScaler scaler) {
    if (!label.contains(' ')) return _measure(label, scaler);
    var longest = 0.0;
    for (final word in label.split(' ')) {
      longest = math.max(longest, _measure(word, scaler));
    }
    return longest;
  }

  static double _weight(String label) {
    return math.max(48, _contentWidth(label, TextScaler.noScaling) + 4);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 500);
    final weights = [for (final item in destinations) _weight(item.label)];

    return Material(
      color: scheme.surfaceContainer,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: MediaQuery.withClampedTextScaling(
          minScaleFactor: 1,
          maxScaleFactor: 1.3,
          child: Semantics(
            key: const Key('adaptive-nav-bar'),
            role: SemanticsRole.tabBar,
            explicitChildNodes: true,
            container: true,
            child: SizedBox(
              height: 80,
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      flex: (weights[index] * 100).round(),
                      child: _Destination(
                        destination: destinations[index],
                        selected: index == selectedIndex,
                        index: index,
                        count: destinations.length,
                        duration: duration,
                        onSelected: onSelected,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.index,
    required this.count,
    required this.duration,
    required this.onSelected,
  });

  final AdaptiveNavDestination destination;
  final bool selected;
  final int index;
  final int count;
  final Duration duration;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = destination.label;
    final scaler = MediaQuery.textScalerOf(context);
    // El cuadro del glifo puede sobresalir 0,1 px del ancho medido. Esa
    // holgura no entra en el peso de la ranura.
    final blockWidth = AdaptiveNavBar._contentWidth(label, scaler) + 0.25;

    return Semantics(
      key: Key('adaptive-nav-slot-$index'),
      role: SemanticsRole.tab,
      selected: selected,
      button: true,
      onTap: () => onSelected(index),
      label: 'Pestaña ${index + 1} de $count',
      child: Tooltip(
        message: label,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: () => onSelected(index),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final indicatorWidth = math.min(
                      64.0,
                      constraints.maxWidth - 4,
                    );
                    return SizedBox(
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (selected)
                            AnimatedContainer(
                              key: const Key('adaptive-nav-indicator'),
                              duration: duration,
                              width: indicatorWidth,
                              height: 32,
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          Icon(
                            selected
                                ? destination.selectedIcon
                                : destination.icon,
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: blockWidth,
                      child: DefaultTextStyle(
                        style: AdaptiveNavBar._labelStyle.copyWith(
                          color: scheme.onSurface,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: label.contains(' ') ? 2 : 1,
                          softWrap: label.contains(' '),
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
