import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/home/screens/home_screen.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart' show unmountApp;
import '../cuenta/account_test_support.dart' show RecordingAccountRepository;

/// La sesión de prueba: autenticada con el rol que se pide.
class _RoleSession extends SessionNotifier {
  _RoleSession(this.role);

  final UserRole role;

  @override
  SessionState build() => SessionState(
    status: SessionStatus.authenticated,
    role: role,
    accessToken: 'sesion-de-prueba',
  );
}

class _Repo extends FakeAnnouncementsRepository {
  @override
  Future<List<Announcement>> latest() async => [
    Announcement(
      id: 7,
      title: 'Novedad 7',
      publishedAt: DateTime.utc(2026, 11, 7),
    ),
    Announcement(
      id: 8,
      title: 'Novedad 8',
      publishedAt: DateTime.utc(2026, 11, 8),
    ),
  ];
}

/// Monta solo [HomeScreen] con el [role] indicado dentro de un router real de
/// prueba. Cada destino de las secciones del rol y el detalle de la cartelera
/// muestran un texto, y la ubicación se lee del propio router.
Future<GoRouter> _pumpRoleHome(
  WidgetTester tester,
  UserRole role, {
  double width = 1280,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/inicio-de-prueba',
    routes: [
      GoRoute(
        path: '/inicio-de-prueba',
        builder: (context, state) => HomeScreen(role: role),
      ),
      GoRoute(
        path: '/cuenta',
        builder: (context, state) => const Text('destino cuenta'),
      ),
      for (final section in role.sections)
        GoRoute(
          path: role.sectionPath(section),
          builder: (context, state) => Text('destino ${section.slug}'),
          routes: [
            if (section.slug == 'cartelera')
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    Text('detalle ${state.pathParameters['id']}'),
              ),
          ],
        ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(() => _RoleSession(role)),
      announcementsRepositoryProvider.overrideWith((ref) async => _Repo()),
      accountRepositoryProvider.overrideWith(
        (ref) async => RecordingAccountRepository(),
      ),
    ],
  );
  addTearDown(() async {
    await unmountApp(tester);
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: appTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  setUpAll(loadRoboto);

  // Textos del rol escritos a mano (los mismos que muestra Mi cuenta).
  const labels = {
    UserRole.socio: 'Socio',
    UserRole.funcionario: 'Funcionario',
    UserRole.medico: 'Médico',
    UserRole.administrador: 'Administrador',
  };

  // Atajos de cada rol, escritos a mano, sin la sección Inicio.
  const shortcuts = {
    UserRole.socio: ['disponibilidad', 'consultas', 'historia', 'cartelera'],
    UserRole.funcionario: ['turnos', 'llegada', 'agendas', 'cartelera'],
    UserRole.medico: ['turnos', 'pases', 'cartelera'],
    UserRole.administrador: [
      'usuarios',
      'especialidades',
      'consultorios',
      'estadisticas',
      'cartelera',
    ],
  };

  for (final entry in labels.entries) {
    for (final width in [1280.0, 400.0]) {
      testWidgets('${entry.key.name} a $width px muestra el rótulo exacto', (
        tester,
      ) async {
        await _pumpRoleHome(tester, entry.key, width: width);

        expect(find.byKey(const Key('home-user-role')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('home-user-role'))).data,
          entry.value,
        );
        for (final other in labels.values.where((l) => l != entry.value)) {
          expect(find.text(other), findsNothing, reason: other);
        }
      });
    }
  }

  for (final entry in shortcuts.entries) {
    testWidgets('${entry.key.name} muestra sus atajos sin Inicio', (
      tester,
    ) async {
      await _pumpRoleHome(tester, entry.key);

      final shown = [
        for (final element
            in find
                .byWidgetPredicate(
                  (widget) =>
                      widget.key is ValueKey<String> &&
                      (widget.key! as ValueKey<String>).value.startsWith(
                        'home-shortcut-',
                      ),
                )
                .evaluate())
          (element.widget.key! as ValueKey<String>).value.substring(
            'home-shortcut-'.length,
          ),
      ];
      expect(shown, entry.value);
    });
  }

  testWidgets('administrador: un atajo lleva a la sección de ese rol', (
    tester,
  ) async {
    final router = await _pumpRoleHome(tester, UserRole.administrador);

    final shortcut = find.byKey(const Key('home-shortcut-estadisticas'));
    await tester.ensureVisible(shortcut);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();

    expect(_location(router), '/admin/estadisticas');
    expect(find.text('destino estadisticas'), findsOneWidget);
  });

  for (final entry in {
    UserRole.socio: '/socio/cartelera',
    UserRole.funcionario: '/funcionario/cartelera',
    UserRole.medico: '/medico/cartelera',
    UserRole.administrador: '/admin/cartelera',
  }.entries) {
    testWidgets('${entry.key.name}: Ver todas abre la cartelera de su rol', (
      tester,
    ) async {
      final router = await _pumpRoleHome(tester, entry.key);

      await tester.ensureVisible(find.text('Ver todas las novedades'));
      await tester.tap(find.text('Ver todas las novedades'));
      await tester.pumpAndSettle();

      expect(_location(router), entry.value);
    });

    testWidgets('${entry.key.name}: tocar una novedad abre su detalle', (
      tester,
    ) async {
      final router = await _pumpRoleHome(tester, entry.key);

      expect(find.text('Novedad 7'), findsOneWidget);
      await tester.tap(find.byKey(const Key('announcement-7')));
      await tester.pumpAndSettle();

      expect(_location(router), '${entry.value}/7');
      expect(find.text('detalle 7'), findsOneWidget);
    });
  }

  testWidgets('administrador ve las novedades del repositorio, no el vacío', (
    tester,
  ) async {
    await _pumpRoleHome(tester, UserRole.administrador);

    expect(find.text('Novedad 7'), findsOneWidget);
    expect(find.text('Todavía no hay novedades publicadas.'), findsNothing);
  });
}
