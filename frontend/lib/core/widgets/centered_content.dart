import 'package:flutter/material.dart';

/// Envuelve [child] centrado, con un ancho máximo y scroll, para que las
/// pantallas se vean bien tanto en móvil como en web (sin estirarse de
/// borde a borde) y el teclado no tape los campos.
///
/// Por defecto también centra en vertical, que es lo que quieren los
/// formularios cortos. Las pantallas con filtros y resultados que cambian de
/// alto piden [Alignment.topCenter]: así el contenido empieza arriba y los
/// controles no se mueven cuando los resultados crecen o se achican.
///
/// Tiene su propio [ScrollController]: la barra de desplazamiento siempre
/// visible (`AppScrollBehavior`) exige un controlador con una sola posición, y
/// con el compartido de la ruta (`PrimaryScrollController`) fallaba cuando dos
/// pantallas con scroll estaban montadas a la vez, como las pestañas de
/// Estadísticas en medio de la animación.
class CenteredContent extends StatefulWidget {
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
  State<CenteredContent> createState() => _CenteredContentState();
}

class _CenteredContentState extends State<CenteredContent> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment,
      child: SingleChildScrollView(
        controller: _controller,
        padding: widget.padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: widget.child,
        ),
      ),
    );
  }
}
