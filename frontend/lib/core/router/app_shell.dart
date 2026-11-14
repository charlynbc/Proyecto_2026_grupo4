import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/models/user_role.dart';
import 'adaptive_nav_bar.dart';
import 'app_sections.dart';

/// Barra de navegación fija de las secciones de un rol: una barra propia
/// abajo en pantallas angostas, `NavigationRail` al costado en anchas. Un rol
/// con una sola sección no muestra barra.
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
    this.onSectionReopened,
  });

  final StatefulNavigationShell navigationShell;
  final List<AppSection> sections;
  final UserRole role;

  /// Se llama al volver a una sección ya abierta antes, para que refresque
  /// sus datos.
  final void Function(BuildContext context, AppSection section)?
  onSectionReopened;

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

    return _SectionReopenWatcher(
      index: navigationShell.currentIndex,
      onReopened: (context, index) =>
          onSectionReopened?.call(context, sections[index]),
      child: PopScope(
        canPop: navigationShell.currentIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          navigationShell.goBranch(0);
        },
        child: child,
      ),
    );
  }
}

/// Avisa cuando se vuelve a una sección que ya se había abierto antes (no la
/// primera vez, cuando la pantalla recién se arma y pide sus datos sola, ni
/// al tocar la sección que ya está a la vista). Las secciones quedan montadas
/// en segundo plano, así que sin esto una sección mostraría datos viejos al
/// volver. El aviso sale después del cuadro actual: los providers no se
/// modifican durante la construcción.
class _SectionReopenWatcher extends StatefulWidget {
  const _SectionReopenWatcher({
    required this.index,
    required this.onReopened,
    required this.child,
  });

  final int index;
  final void Function(BuildContext context, int index) onReopened;
  final Widget child;

  @override
  State<_SectionReopenWatcher> createState() => _SectionReopenWatcherState();
}

class _SectionReopenWatcherState extends State<_SectionReopenWatcher> {
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(_SectionReopenWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.index;
    if (index == oldWidget.index) return;
    if (!_visited.add(index)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReopened(context, index);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
          ? AdaptiveNavBar(
              destinations: [
                for (final section in destinations)
                  AdaptiveNavDestination(
                    icon: section.icon,
                    selectedIcon: section.selectedIcon,
                    label: section.label,
                  ),
              ],
              selectedIndex: shell.navigationShell.currentIndex - offset,
              onSelected: (index) =>
                  shell._onDestinationSelected(index + offset),
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
