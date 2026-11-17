import 'package:flutter/material.dart';

/// Envuelve [child] centrado, con un ancho máximo y scroll, para que las
/// pantallas se vean bien tanto en móvil como en web (sin estirarse de
/// borde a borde) y el teclado no tape los campos.
///
/// Por defecto también centra en vertical, que es lo que quieren los
/// formularios cortos. Las pantallas con filtros y resultados que cambian de
/// alto piden [Alignment.topCenter]: así el contenido empieza arriba y los
/// controles no se mueven cuando los resultados crecen o se achican.
class CenteredContent extends StatelessWidget {
  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  /// Dónde queda el contenido cuando es más bajo que la pantalla. El ancho
  /// siempre queda centrado: solo cambia la posición vertical.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
