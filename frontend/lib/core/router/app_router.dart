import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agenda/screens/professional_agenda_screen.dart';
import '../../features/agenda/screens/professionals_screen.dart';
import '../../features/auth/providers/session_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/reservas/screens/my_reservations_screen.dart';
import 'app_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _SessionRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;

      return switch (session.status) {
        SessionStatus.checking => location == '/' ? null : '/',
        SessionStatus.unauthenticated
            when location == '/login' || location == '/olvide-password' =>
          null,
        SessionStatus.unauthenticated => '/login',
        SessionStatus.authenticated
            when location == '/' || location == '/login' =>
          '/home',
        SessionStatus.authenticated => null,
      };
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/olvide-password',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Olvidé mi contraseña'),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                builder: (context, state) => const ProfessionalsScreen(),
                routes: [
                  GoRoute(
                    path: ':professionalId',
                    redirect: (context, state) {
                      final id = int.tryParse(
                        state.pathParameters['professionalId'] ?? '',
                      );
                      return id == null ? '/agenda' : null;
                    },
                    builder: (context, state) => ProfessionalAgendaScreen(
                      professionalId: int.parse(
                        state.pathParameters['professionalId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mis-reservas',
                builder: (context, state) => const MyReservationsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Puente entre sessionProvider y GoRouter: cada cambio de sesión notifica a
/// GoRouter para que vuelva a correr `redirect` sobre la ubicación actual.
/// Sin esto, `redirect` sigue siendo correcto pero nunca se re-evalúa solo,
/// así que la navegación no reacciona a login/logout/expiración hasta la
/// próxima navegación manual.
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
