import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/providers/session_provider.dart';
import '../services/push_navigation_controller.dart';
import 'notification_list_provider.dart';
import 'push_notification_provider.dart';

/// Abre las rutas de un push: la primera con `go` y, si hay una segunda, la
/// apila encima con `push` cuando `go` ya terminó (después del cuadro
/// siguiente). Así el detalle queda sobre Avisos y Atrás vuelve a Avisos.
Future<void> openPushRoutes(GoRouter router, List<String> routes) async {
  router.go(routes.first);
  if (routes.length < 2) return;
  await WidgetsBinding.instance.endOfFrame;
  unawaited(router.push<void>(routes[1]));
}

/// Un solo controlador para toda la app: `main.dart` lo arranca al abrirse y
/// le avisa de cada cambio de sesión.
final pushNavigationControllerProvider = Provider<PushNavigationController>((
  ref,
) {
  final controller = PushNavigationController(
    service: ref.watch(pushNotificationServiceProvider),
    session: () => ref.read(sessionProvider),
    navigate: (routes) => openPushRoutes(ref.read(goRouterProvider), routes),
    refreshNotifications: () {
      ref.read(notificationListRefreshProvider.notifier).refresh();
      ref.read(notificationListReopenedProvider.notifier).reopened();
    },
  );
  ref.onDispose(controller.stop);
  return controller;
});
