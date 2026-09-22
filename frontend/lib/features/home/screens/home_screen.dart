import 'package:flutter/material.dart';

import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';

/// Home provisoria: un saludo simple. La navegación a las demás secciones y
/// el cierre de sesión los da la barra de navegación fija.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: const [LogoutButton()],
      ),
      body: const CenteredContent(
        child: Center(child: Text('¡Hola! Elegí una sección en el menú.')),
      ),
    );
  }
}
