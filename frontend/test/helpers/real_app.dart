import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RoleSession extends SessionNotifier {
  _RoleSession(this.role);
  final UserRole role;

  @override
  SessionState build() => SessionState(
    status: SessionStatus.authenticated,
    role: role,
    accessToken: 'test-session',
  );
}

/// Monta el `MyApp` de verdad (el de `main.dart`, con su tema y su
/// `ScrollBehavior`) con datos falsos y la sesión de [role] ya iniciada, y
/// abre [location]. [size] es el tamaño de la pantalla en píxeles lógicos y
/// [textScale] el tamaño del texto del sistema.
Future<ProviderContainer> pumpRealAppAs(
  WidgetTester tester,
  UserRole role,
  String location, {
  Size size = const Size(900, 700),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        useFakesProvider.overrideWithValue(true),
        sessionProvider.overrideWith(() => _RoleSession(role)),
      ],
      child: const MyApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MyApp)),
  );
  container.read(goRouterProvider).go(location);
  await tester.pumpAndSettle();
  return container;
}
