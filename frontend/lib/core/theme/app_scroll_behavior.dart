import 'package:flutter/material.dart';

/// El comportamiento de desplazamiento de toda la app (`MaterialApp.scrollBehavior`).
///
/// Flutter solo dibuja la barra vertical en escritorio y web, y solo mientras
/// se desliza o con el mouse encima; en Android y en iOS no la dibuja. Acá se
/// dibuja en todas las plataformas, y si va siempre visible o no lo decide el
/// `scrollbarTheme` del tema (`appTheme`): así hay un solo lugar para cada
/// cosa.
///
/// El desplazamiento horizontal sigue como estaba: sin barra propia (las
/// tablas que quieren una la declaran en su pantalla).
///
/// Ojo: la barra siempre visible exige un controlador con una sola posición.
/// En Android todo desplazable vertical sin controlador hereda el
/// `PrimaryScrollController` de la ruta, así que dos a la vez en la misma
/// ruta (las pestañas de Estadísticas en medio de la animación) lo comparten y
/// fallan: por eso `CenteredContent` tiene su propio controlador.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) {
      return super.buildScrollbar(context, child, details);
    }
    // En iOS Flutter usa la barra de Cupertino, que no mira el tema: se le
    // pasa lo que el tema dice para que también ahí sea visible y gruesa.
    final theme = ScrollbarTheme.of(context);
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: theme.thumbVisibility?.resolve(const {}),
      thickness: theme.thickness?.resolve(const {}),
      radius: theme.radius,
      child: child,
    );
  }
}
