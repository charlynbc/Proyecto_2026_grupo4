import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Barra de navegación fija de las tres secciones autenticadas: `NavigationBar`
/// abajo en pantallas angostas, `NavigationRail` al costado en anchas.
///
/// Intercepta el botón de atrás de Android con [PopScope]: parado en la raíz
/// de Agenda o de Mis reservas, atrás vuelve a Inicio en vez de cerrar la
/// app. go_router resuelve antes que este `PopScope` si hay algo para hacer
/// pop dentro de la sección activa (por ejemplo, del detalle de un
/// profesional a la lista), así que acá no hace falta chequear la
/// profundidad de la rama: si el intento llega hasta este `PopScope` es
/// porque la rama activa ya está en su raíz.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Inicio',
    ),
    (
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Agenda',
    ),
    (
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
      label: 'Mis reservas',
    ),
  ];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        navigationShell.goBranch(0);
      },
      child: isWide ? _WideShell(this) : _NarrowShell(this),
    );
  }
}

class _NarrowShell extends StatelessWidget {
  const _NarrowShell(this.shell);

  final AppShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.navigationShell.currentIndex,
        onDestinationSelected: shell._onDestinationSelected,
        destinations: [
          for (final destination in AppShell._destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell(this.shell);

  final AppShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.navigationShell.currentIndex,
            onDestinationSelected: shell._onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final destination in AppShell._destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell.navigationShell),
        ],
      ),
    );
  }
}
