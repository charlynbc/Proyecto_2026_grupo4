import 'package:flutter/material.dart';

const double _spacing = 12;

/// El paginador compartido: Anterior, el texto de página y Siguiente.
///
/// Cada pantalla arma su propio [label] ("Página 2 de 5 · 93 cuentas") y
/// decide qué hacen los botones. Anterior se deshabilita si no [hasPrevious]
/// y Siguiente si no [hasNext].
///
/// Si los tres controles entran en una fila (con el texto real y la escala de
/// texto del sistema), van en un `Wrap` centrado. Si no entran, el texto de
/// página va arriba y Anterior y Siguiente lado a lado debajo: así Siguiente
/// nunca queda sola en un segundo renglón. A 320 px, y con texto grande, es lo
/// que pasa; en una pantalla ancha no cambia nada.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.label,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    this.previousKey,
    this.nextKey,
  });

  final String label;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Las keys de cada botón, para las pantallas que ya las usan.
  final Key? previousKey;
  final Key? nextKey;

  /// Un solo aspecto en toda la app: botones con borde.
  Widget _button(Key? key, String text, bool enabled, VoidCallback onTap) {
    return OutlinedButton(
      key: key,
      onPressed: enabled ? onTap : null,
      child: Text(text),
    );
  }

  /// Si Anterior, el texto y Siguiente entran en [maxWidth] en una sola fila.
  /// Mide los textos con la fuente y la escala reales; el relleno de los
  /// botones con borde es el de Material (24 a cada lado).
  bool _fitsInOneRow(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite) return true;
    final scaler = MediaQuery.textScalerOf(context);
    double textWidth(String text, TextStyle? textStyle) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    const padding = 48.0;
    final buttonText = Theme.of(context).textTheme.labelLarge;
    double button(String text) =>
        (textWidth(text, buttonText) + padding).clamp(64.0, double.infinity);
    final needed =
        button('Anterior') +
        textWidth(label, DefaultTextStyle.of(context).style) +
        button('Siguiente') +
        2 * _spacing +
        2; // margen por redondeos
    return needed <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final previous = _button(previousKey, 'Anterior', hasPrevious, onPrevious);
    final next = _button(nextKey, 'Siguiente', hasNext, onNext);
    final page = Text(label, textAlign: TextAlign.center);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_fitsInOneRow(context, constraints.maxWidth)) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              page,
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: _spacing,
                runSpacing: 12,
                children: [previous, next],
              ),
            ],
          );
        }
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: _spacing,
          runSpacing: 12,
          children: [previous, page, next],
        );
      },
    );
  }
}
