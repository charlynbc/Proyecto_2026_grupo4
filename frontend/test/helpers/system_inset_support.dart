import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// Barra de botones del sistema de Android de 48 dp, la del celular donde se
/// vio el problema (Android 15 o superior dibuja la app detrás de ella).
const double kSystemNavigationBar = 48;

/// Alto fijo de 600 dp: hace que las pantallas tengan scroll.
const Size kNarrowPhone = Size(400, 600);
const Size kWidePhone = Size(900, 600);

/// Monta la app con [bottom] dp de padding inferior del sistema, inicia
/// sesión como [role] y la deja lista (sin ir a ninguna ruta).
Future<ProviderContainer> pumpAsWithInset(
  WidgetTester tester,
  UserRole role, {
  required Size size,
  required double bottom,
}) async {
  tester.view.padding = FakeViewPadding(bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(bottom: bottom);
  final container = await pumpApp(tester, size: size);
  final person = TestData.people.firstWhere((p) => p.role == role.apiValue);
  final repo = await container.read(authRepositoryProvider.future);
  final login = repo.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.forRole(role),
  );
  await tester.pumpAndSettle();
  await login;
  await tester.pumpAndSettle();
  return container;
}

/// Lleva el scroll principal hasta el final.
Future<void> scrollToEnd(WidgetTester tester) async {
  await tester.drag(
    find.byType(SingleChildScrollView).first,
    const Offset(0, -5000),
  );
  await tester.pumpAndSettle();
}

double bottomOf(WidgetTester tester, Finder finder) =>
    tester.getBottomLeft(finder).dy;
