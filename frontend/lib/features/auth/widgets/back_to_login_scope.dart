import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/intercept_back_provider.dart';

/// Hace que el botón de atrás de Android lleve a [loginPath] desde las
/// pantallas que se abren fuera del ingreso (pedir el enlace, activar la
/// cuenta, elegir la contraseña nueva). Sin esto, el atrás cierra la app
/// porque no queda ninguna pantalla debajo.
///
/// En la web no hace nada (ver [interceptSystemBackProvider]).
class BackToLoginScope extends ConsumerWidget {
  const BackToLoginScope({
    super.key,
    required this.loginPath,
    required this.child,
  });

  final String loginPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(interceptSystemBackProvider)) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(loginPath);
      },
      child: child,
    );
  }
}
