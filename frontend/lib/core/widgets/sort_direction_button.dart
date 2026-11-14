import 'package:flutter/material.dart';

/// El botón del sentido del orden de los listados: muestra el sentido actual
/// ("Ascendente" con la flecha hacia arriba, "Descendente" con la flecha hacia
/// abajo) y, al tocarlo, avisa con [onPressed] para que quien lo usa lo
/// invierta. Es el mismo botón que usa el listado de usuarios.
class SortDirectionButton extends StatelessWidget {
  const SortDirectionButton({
    super.key,
    required this.ascending,
    required this.onPressed,
  });

  final bool ascending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
      label: Text(ascending ? 'Ascendente' : 'Descendente'),
    );
  }
}
