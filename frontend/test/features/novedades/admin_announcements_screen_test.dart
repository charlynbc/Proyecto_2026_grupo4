import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import 'admin_test_support.dart';

typedef _Repo = AdminTestRepo;

Future<ProviderContainer> _pump(
  WidgetTester tester,
  AdminTestRepo repo, {
  double width = 1280,
  double scale = 1,
  UserRole role = UserRole.administrador,
}) => pumpAdminScreen(tester, repo, width: width, scale: scale, role: role);

Finder _card(int id) => find.byKey(ValueKey('admin-announcement-$id'));

Finder _inCard(int id, String text) =>
    find.descendant(of: _card(id), matching: find.text(text));

Finder _delete(int id) => find.byKey(ValueKey('admin-delete-$id'));

Future<void> _tapDelete(WidgetTester tester, int id) async {
  await tester.ensureVisible(_delete(id));
  await tester.tap(_delete(id));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('el título de la pantalla es Cartelera', (tester) async {
    await _pump(tester, _Repo());

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Cartelera'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cada novedad muestra su estado como texto', (tester) async {
    await _pump(tester, _Repo());

    expect(_inCard(30, 'Vigente'), findsOneWidget);
    expect(_inCard(20, 'Programado'), findsOneWidget);
    expect(_inCard(10, 'Vencido'), findsOneWidget);
    // El estado no se confunde con el de otra fila.
    expect(_inCard(30, 'Vencido'), findsNothing);
    expect(_inCard(10, 'Vigente'), findsNothing);
  });

  testWidgets('muestra las novedades en el orden del servidor', (tester) async {
    await _pump(tester, _Repo());

    final tops = [
      for (final id in [30, 20, 10]) tester.getTopLeft(_card(id)).dy,
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
  });

  testWidgets('muestra las fechas de vigencia en hora de Uruguay', (
    tester,
  ) async {
    await _pump(tester, _Repo());

    expect(_inCard(30, 'Se ve desde: la publicación'), findsOneWidget);
    expect(_inCard(30, 'Se deja de ver: 01/12/2026 00:00'), findsOneWidget);
    expect(_inCard(20, 'Se ve desde: 20/11/2026 00:00'), findsOneWidget);
    expect(_inCard(20, 'Se deja de ver: 20/11/2026 23:59'), findsOneWidget);
    expect(_inCard(10, 'Se deja de ver: 01/11/2026 00:00'), findsOneWidget);
  });

  testWidgets('muestra la posición en el carrusel solo si la tiene', (
    tester,
  ) async {
    await _pump(tester, _Repo());

    expect(_inCard(30, 'En el carrusel: posición 2'), findsOneWidget);
    expect(find.textContaining('En el carrusel'), findsOneWidget);
  });

  testWidgets('mientras carga muestra el aviso de carga', (tester) async {
    final repo = _Repo()..listPending = Completer<void>();
    await _pump(tester, repo);

    expect(find.text('Cargando novedades…'), findsOneWidget);

    repo.listPending!.complete();
    await tester.pumpAndSettle();
    expect(_card(30), findsOneWidget);
  });

  testWidgets('sin novedades muestra el aviso de vacío', (tester) async {
    await _pump(tester, _Repo(seed: const []));

    expect(find.text('Todavía no hay novedades publicadas.'), findsOneWidget);
  });

  testWidgets('un error muestra el mensaje y permite reintentar', (
    tester,
  ) async {
    final repo = _Repo()
      ..listError = const ApiException('Servicio de prueba caído');
    await _pump(tester, repo);

    expect(find.text('No pudimos cargar las novedades.'), findsOneWidget);
    expect(find.text('Servicio de prueba caído'), findsOneWidget);

    repo.listError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(_card(30), findsOneWidget);
    expect(find.text('No pudimos cargar las novedades.'), findsNothing);
    expect(repo.listCalls, 2);
  });

  group('eliminar', () {
    testWidgets('pide confirmación y avisa que es definitivo', (tester) async {
      final repo = _Repo();
      await _pump(tester, repo);

      await _tapDelete(tester, 20);

      expect(find.text('¿Eliminar esta novedad?'), findsOneWidget);
      expect(find.textContaining('para siempre'), findsOneWidget);
      expect(find.textContaining('cartelera y del carrusel'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
      expect(find.text('Eliminar novedad'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('volver no elimina nada', (tester) async {
      final repo = _Repo();
      await _pump(tester, repo);
      await _tapDelete(tester, 20);

      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(repo.calls, isEmpty);
      expect(_card(20), findsOneWidget);
      expect(find.text('¿Eliminar esta novedad?'), findsNothing);
    });

    testWidgets('confirmar elimina, quita la fila y avisa', (tester) async {
      final repo = _Repo();
      await _pump(tester, repo);
      await _tapDelete(tester, 20);

      await tester.tap(find.text('Eliminar novedad'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['delete:20']);
      expect(_card(20), findsNothing);
      expect(_card(30), findsOneWidget);
      expect(find.text('Novedad eliminada'), findsOneWidget);
    });

    testWidgets('si otro administrador ya la eliminó, muestra el mensaje y '
        'actualiza la lista', (tester) async {
      final repo = _Repo();
      await _pump(tester, repo);
      await repo.deleteBehindTheScenes(20);
      await _tapDelete(tester, 20);

      await tester.tap(find.text('Eliminar novedad'));
      await tester.pumpAndSettle();

      expect(find.text('Anuncio no encontrado'), findsOneWidget);
      expect(_card(20), findsNothing);
      expect(_card(30), findsOneWidget);
    });

    testWidgets('un error del servidor se muestra y la fila queda', (
      tester,
    ) async {
      final repo = _Repo()
        ..deleteError = const ApiException(
          'No pudimos eliminar, probá de nuevo',
        );
      await _pump(tester, repo);
      await _tapDelete(tester, 20);

      await tester.tap(find.text('Eliminar novedad'));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos eliminar, probá de nuevo'), findsOneWidget);
      expect(_card(20), findsOneWidget);
    });

    testWidgets('mientras elimina, los botones quedan deshabilitados y no se '
        'duplica el envío', (tester) async {
      final repo = _Repo()..deletePending = Completer<void>();
      await _pump(tester, repo);
      await _tapDelete(tester, 20);

      await tester.tap(find.text('Eliminar novedad'));
      // El diálogo termina de cerrarse; la eliminación sigue pendiente.
      await tester.pumpAndSettle();

      for (final id in [30, 20, 10]) {
        expect(
          tester.widget<TextButton>(_delete(id)).onPressed,
          isNull,
          reason: 'eliminar $id',
        );
      }
      await tester.tap(_delete(20), warnIfMissed: false);
      await tester.pump();
      expect(find.text('¿Eliminar esta novedad?'), findsNothing);
      expect(repo.calls, ['delete:20']);

      repo.deletePending!.complete();
      await tester.pumpAndSettle();
      expect(_card(20), findsNothing);
      expect(repo.calls, ['delete:20']);
    });
  });

  group('navegación', () {
    for (final role in [
      UserRole.socio,
      UserRole.funcionario,
      UserRole.medico,
    ]) {
      for (final path in [
        '/admin/cartelera/carrusel',
        '/admin/cartelera/20/vigencia',
      ]) {
        testWidgets('${role.name} no llega a $path', (tester) async {
          final container = await _pump(tester, _Repo(), role: role);

          await goTo(tester, container, path);

          expect(locationOf(container), role.homePath);
        });
      }
    }
  });

  group('a 320 px con texto al doble', () {
    testWidgets('las acciones y los textos no se cortan ni desbordan', (
      tester,
    ) async {
      await _pump(tester, _Repo(), width: 320, scale: 2);

      expect(tester.takeException(), isNull);
      for (final id in [30, 20, 10]) {
        for (final key in ['admin-validity-$id', 'admin-delete-$id']) {
          final finder = find.byKey(ValueKey(key));
          await tester.ensureVisible(finder);
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0), reason: key);
          expect(rect.right, lessThanOrEqualTo(320), reason: key);
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el diálogo de confirmación cabe sin desbordar', (
      tester,
    ) async {
      await _pump(tester, _Repo(), width: 320, scale: 2);

      await _tapDelete(tester, 20);

      expect(find.text('Eliminar novedad'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
