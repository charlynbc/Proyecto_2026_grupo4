import 'package:flutter/material.dart';

/// Envuelve [child] centrado, con un ancho máximo y scroll, para que las
/// pantallas se vean bien tanto en móvil como en web (sin estirarse de
/// borde a borde) y el teclado no tape los campos.
class CenteredContent extends StatelessWidget {
  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
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
