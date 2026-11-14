import 'package:flutter/material.dart';

/// Reserva debajo de [child] el espacio de la barra de navegación del sistema
/// (los botones de Android), para que el contenido no quede dibujado por
/// detrás de ella.
///
/// Desde Android 15 la app se dibuja de borde a borde y `Scaffold` no aplica
/// ese espacio al cuerpo cuando no tiene `bottomNavigationBar`. Hay que usar
/// este widget en toda pantalla que se muestre **sin barra inferior propia**.
///
/// - Con barra inferior propia (`AdaptiveNavBar`) no hace falta: ella reserva
///   el espacio con su `SafeArea`, y usarlo también lo duplicaría.
/// - Quita ese padding del `MediaQuery` de [child], así que una `SafeArea` o
///   un `Scaffold` de adentro no lo suman otra vez.
/// - Con padding inferior 0 (web, escritorio, Android sin barra de botones)
///   no cambia nada. El teclado no cuenta: `Scaffold` lo maneja aparte.
/// - La franja reservada se pinta con el fondo del tema, para que no se vea
///   el color de la ventana de Android.
class BottomSystemInset extends StatelessWidget {
  const BottomSystemInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: child,
        ),
      ),
    );
  }
}
