import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/models/user_role.dart';
import 'app_sections.dart';

/// Barra de navegación fija de las secciones de un rol: `NavigationBar` abajo
/// en pantallas angostas, `NavigationRail` al costado en anchas. Un rol con
/// una sola sección no muestra barra.
/// Inicio usa sus accesos propios; el menú se conserva en las demás secciones.
///
/// Intercepta el botón de atrás de Android con [PopScope]: parado en la raíz
/// de cualquier sección que no sea la primera, atrás vuelve a la primera en
/// vez de cerrar la app. go_router resuelve antes que este `PopScope` si hay
/// algo para hacer pop dentro de la sección activa, así que acá no hace falta
/// chequear la profundidad de la rama: si el intento llega hasta este
/// `PopScope` es porque la rama activa ya está en su raíz.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.sections,
    required this.role,
  });

  final StatefulNavigationShell navigationShell;
  final List<AppSection> sections;
  final UserRole role;

  bool get _showNavigation =>
      sections[navigationShell.currentIndex].slug != 'inicio';

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (sections.length < 2) {
      child = navigationShell;
    } else if (MediaQuery.sizeOf(context).width >= 600) {
      child = _WideShell(this);
    } else {
      child = _NarrowShell(this);
    }

    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        navigationShell.goBranch(0);
      },
      child: child,
    );
  }
}

class _NarrowShell extends StatelessWidget {
  const _NarrowShell(this.shell);

  final AppShell shell;

  @override
  Widget build(BuildContext context) {
    final offset = shell.role == UserRole.socio ? 0 : 1;
    final destinations = shell.sections.skip(offset).toList();
    return Scaffold(
      body: shell.navigationShell,
      bottomNavigationBar: shell._showNavigation && destinations.length >= 2
          ? NavigationBarTheme(
              data: const NavigationBarThemeData(
                labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
                labelPadding: EdgeInsets.zero,
              ),
              child: NavigationBar(
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                selectedIndex: shell.navigationShell.currentIndex - offset,
                onDestinationSelected: (index) =>
                    shell._onDestinationSelected(index + offset),
                destinations: [
                  for (final section in destinations)
                    DefaultTextStyle.merge(
                      textAlign: TextAlign.center,
                      // Mantener las etiquetas de una palabra en una línea.
                      // El tooltip conserva el nombre completo.
                      softWrap: section.label.contains(' '),
                      overflow: section.label.contains(' ')
                          ? null
                          : TextOverflow.ellipsis,
                      child: NavigationDestination(
                        icon: Icon(section.icon),
                        selectedIcon: Icon(section.selectedIcon),
                        label: section.label,
                      ),
                    ),
                ],
              ),
            )
          : null,
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
          if (shell._showNavigation) ...[
            NavigationRail(
              selectedIndex: shell.navigationShell.currentIndex,
              onDestinationSelected: shell._onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final section in shell.sections)
                  NavigationRailDestination(
                    icon: Icon(section.icon),
                    selectedIcon: Icon(section.selectedIcon),
                    label: Text(section.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            key: const ValueKey('section-content'),
            child: shell.navigationShell,
          ),
        ],
      ),
    );
  }
}
