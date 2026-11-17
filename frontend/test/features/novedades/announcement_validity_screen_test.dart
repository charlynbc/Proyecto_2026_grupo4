import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/screens/announcement_validity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import 'admin_test_support.dart';

const _endMessage =
    'La fecha de fin es obligatoria y debe ser posterior al inicio';

const _fromDate = 'Visible desde: fecha';
const _fromTime = 'Visible desde: hora';
const _untilDate = 'Visible hasta: fecha';
const _untilTime = 'Visible hasta: hora';

Finder _field(String label) => find.widgetWithText(TextFormField, label);

String _text(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(_field(label)).controller!.text;

Future<void> _open(
  WidgetTester tester,
  AdminTestRepo repo,
  int id, {
  double width = 1280,
  double scale = 1,
}) async {
  await pumpAdminScreen(
    tester,
    repo,
    width: width,
    scale: scale,
    location: '/admin/cartelera/$id/vigencia',
  );
}

Future<void> _save(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Guardar vigencia');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _clearUntil(WidgetTester tester) async {
  await tester.enterText(_field(_untilDate), '');
  await tester.enterText(_field(_untilTime), '');
  await tester.pump();
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('abre con los datos de la novedad ya cargados', (tester) async {
    await _open(tester, AdminTestRepo(), 20);

    expect(find.text('Horarios de verano'), findsOneWidget);
    expect(find.text('Programado'), findsOneWidget);
    expect(_text(tester, _fromDate), '20/11/2026');
    expect(_text(tester, _fromTime), '00:00');
    expect(_text(tester, _untilDate), '20/11/2026');
    expect(_text(tester, _untilTime), '23:59');
  });

  testWidgets('sin inicio deja vacío el inicio y completa el fin', (
    tester,
  ) async {
    await _open(tester, AdminTestRepo(), 30);

    expect(_text(tester, _fromDate), isEmpty);
    expect(_text(tester, _fromTime), isEmpty);
    expect(_text(tester, _untilDate), '01/12/2026');
    expect(_text(tester, _untilTime), '00:00');
  });

  testWidgets('el título de la pantalla es Cambiar vigencia', (tester) async {
    await _open(tester, AdminTestRepo(), 30);

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Cambiar vigencia'),
      ),
      findsOneWidget,
    );
  });

  group('validación en el cliente', () {
    testWidgets('sin fecha de fin no se guarda', (tester) async {
      final repo = AdminTestRepo();
      await _open(tester, repo, 30);
      await _clearUntil(tester);

      await _save(tester);

      expect(repo.validityCalls, isEmpty);
      expect(find.text(_endMessage), findsOneWidget);
    });

    testWidgets('fin igual al inicio no se guarda', (tester) async {
      final repo = AdminTestRepo();
      await _open(tester, repo, 20);
      await tester.enterText(_field(_untilDate), '20/11/2026');
      await tester.enterText(_field(_untilTime), '00:00');

      await _save(tester);

      expect(repo.validityCalls, isEmpty);
      expect(find.text(_endMessage), findsOneWidget);
    });

    testWidgets('fin anterior al inicio no se guarda', (tester) async {
      final repo = AdminTestRepo();
      await _open(tester, repo, 20);
      await tester.enterText(_field(_untilDate), '19/11/2026');

      await _save(tester);

      expect(repo.validityCalls, isEmpty);
      expect(find.text(_endMessage), findsOneWidget);
    });

    testWidgets('sin inicio, un fin que ya pasó no se guarda', (tester) async {
      final repo = AdminTestRepo();
      await _open(tester, repo, 30);
      await tester.enterText(_field(_untilDate), '14/11/2026');
      await tester.enterText(_field(_untilTime), '11:59');

      await _save(tester);

      expect(repo.validityCalls, isEmpty);
      expect(find.text(_endMessage), findsOneWidget);
    });

    testWidgets('una hora sin fecha pide la fecha', (tester) async {
      final repo = AdminTestRepo();
      await _open(tester, repo, 30);
      await tester.enterText(_field(_fromTime), '10:00');

      await _save(tester);

      expect(repo.validityCalls, isEmpty);
      expect(find.text('Elegí la fecha.'), findsOneWidget);
    });
  });

  group('guardar', () {
    testWidgets('manda inicio y fin como instantes de Uruguay y vuelve a la '
        'Cartelera con el aviso', (tester) async {
      final repo = AdminTestRepo();
      final container = await pumpAdminScreen(
        tester,
        repo,
        location: '/admin/cartelera/20/vigencia',
      );
      await tester.enterText(_field(_fromDate), '25/11/2026');
      await tester.enterText(_field(_untilDate), '30/11/2026');

      await _save(tester);

      // 25/11 00:00 -03:00 = 03:00 UTC; 30/11 23:59 -03:00 = 01/12 02:59 UTC.
      expect(repo.validityCalls.single.id, 20);
      expect(repo.validityCalls.single.from, DateTime.utc(2026, 11, 25, 3));
      expect(repo.validityCalls.single.until, DateTime.utc(2026, 12, 1, 2, 59));
      expect(locationOf(container), '/admin/cartelera');
      expect(find.text('Vigencia actualizada'), findsOneWidget);
      expect(find.text('Se ve desde: 25/11/2026 00:00'), findsOneWidget);
      expect(find.text('Se deja de ver: 30/11/2026 23:59'), findsOneWidget);
    });

    testWidgets('sin inicio manda el inicio en null', (tester) async {
      final repo = AdminTestRepo();
      await _open(tester, repo, 30);
      await tester.enterText(_field(_untilDate), '05/12/2026');

      await _save(tester);

      expect(repo.validityCalls.single.from, isNull);
      // 05/12 00:00 -03:00 = 03:00 UTC.
      expect(repo.validityCalls.single.until, DateTime.utc(2026, 12, 5, 3));
    });

    testWidgets('quitar el inicio de una novedad que lo tenía manda null', (
      tester,
    ) async {
      final repo = AdminTestRepo();
      await _open(tester, repo, 20);
      await tester.enterText(_field(_fromDate), '');
      await tester.enterText(_field(_fromTime), '');
      await tester.enterText(_field(_untilDate), '30/11/2026');

      await _save(tester);

      expect(repo.validityCalls.single.from, isNull);
    });

    testWidgets('un 400 del servidor muestra su mensaje y no cierra', (
      tester,
    ) async {
      final repo = AdminTestRepo()
        ..validityError = const ApiException('El fin debe ser posterior');
      final container = await pumpAdminScreen(
        tester,
        repo,
        location: '/admin/cartelera/30/vigencia',
      );
      await tester.enterText(_field(_untilDate), '05/12/2026');

      await _save(tester);

      expect(find.text('El fin debe ser posterior'), findsOneWidget);
      expect(locationOf(container), '/admin/cartelera/30/vigencia');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardar vigencia'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('un 404 (otra persona la eliminó) muestra el mensaje', (
      tester,
    ) async {
      final repo = AdminTestRepo();
      await _open(tester, repo, 20);
      await repo.deleteBehindTheScenes(20);
      await tester.enterText(_field(_untilDate), '30/11/2026');

      await _save(tester);

      expect(find.text('Anuncio no encontrado'), findsOneWidget);
    });

    testWidgets('mientras guarda deshabilita el botón y no duplica el '
        'envío', (tester) async {
      final repo = AdminTestRepo()..validityPending = Completer<void>();
      await _open(tester, repo, 30);
      await tester.enterText(_field(_untilDate), '05/12/2026');
      final save = find.widgetWithText(FilledButton, 'Guardar vigencia');
      await tester.ensureVisible(save);

      await tester.tap(save);
      await tester.pump();

      final saving = find.widgetWithText(FilledButton, 'Guardando…');
      expect(saving, findsOneWidget);
      expect(tester.widget<FilledButton>(saving).onPressed, isNull);
      await tester.tap(saving, warnIfMissed: false);
      await tester.pump();
      expect(repo.validityCalls, hasLength(1));

      repo.validityPending!.complete();
      await tester.pumpAndSettle();
      expect(repo.validityCalls, hasLength(1));
      expect(find.text('Vigencia actualizada'), findsOneWidget);
    });
  });

  group('estados de carga', () {
    testWidgets('mientras carga muestra el aviso', (tester) async {
      final repo = AdminTestRepo()..listPending = Completer<void>();
      await _open(tester, repo, 30);

      expect(find.text('Cargando novedad…'), findsOneWidget);

      repo.listPending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Jornada de vacunación'), findsOneWidget);
    });

    testWidgets('un error de carga permite reintentar', (tester) async {
      final repo = AdminTestRepo()
        ..listError = const ApiException('Servicio de prueba caído');
      await _open(tester, repo, 30);

      expect(find.text('No pudimos cargar la novedad.'), findsOneWidget);
      expect(find.text('Servicio de prueba caído'), findsOneWidget);

      repo.listError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Jornada de vacunación'), findsOneWidget);
    });

    testWidgets('una novedad que no existe lo dice y ofrece volver', (
      tester,
    ) async {
      final container = await pumpAdminScreen(
        tester,
        AdminTestRepo(),
        location: '/admin/cartelera/99/vigencia',
      );

      expect(
        find.textContaining('No encontramos esta novedad'),
        findsOneWidget,
      );

      await tester.tap(find.text('Volver a la Cartelera'));
      await tester.pumpAndSettle();
      expect(locationOf(container), '/admin/cartelera');
    });
  });

  group('navegación', () {
    testWidgets('Cambiar vigencia abre la pantalla de esa novedad', (
      tester,
    ) async {
      await pumpAdminScreen(tester, AdminTestRepo());

      final button = find.byKey(const ValueKey('admin-validity-20'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(AnnouncementValidityScreen), findsOneWidget);
      expect(_text(tester, _untilDate), '20/11/2026');
      expect(find.text('Guardar vigencia'), findsOneWidget);
    });

    testWidgets('un identificador inválido vuelve a la Cartelera', (
      tester,
    ) async {
      final container = await pumpAdminScreen(
        tester,
        AdminTestRepo(),
        location: '/admin/cartelera/abc/vigencia',
      );

      expect(locationOf(container), '/admin/cartelera');
    });

    testWidgets('Cancelar vuelve sin guardar', (tester) async {
      final repo = AdminTestRepo();
      await pumpAdminScreen(tester, repo);
      final button = find.byKey(const ValueKey('admin-validity-30'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(AnnouncementValidityScreen), findsOneWidget);

      final cancel = find.widgetWithText(OutlinedButton, 'Cancelar');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(find.byType(AnnouncementValidityScreen), findsNothing);
      expect(
        find.byKey(const ValueKey('admin-announcement-30')),
        findsOneWidget,
      );
      expect(repo.validityCalls, isEmpty);
    });
  });

  group('a 320 px con texto al doble', () {
    testWidgets('los cuatro campos y el botón entran sin desbordar', (
      tester,
    ) async {
      await _open(tester, AdminTestRepo(), 20, width: 320, scale: 2);

      expect(tester.takeException(), isNull);
      for (final label in [_fromDate, _fromTime, _untilDate, _untilTime]) {
        await tester.ensureVisible(_field(label));
        final rect = tester.getRect(_field(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
      }
      final save = find.widgetWithText(FilledButton, 'Guardar vigencia');
      await tester.ensureVisible(save);
      expect(tester.getRect(save).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('con el mensaje de error a la vista tampoco desborda', (
      tester,
    ) async {
      await _open(tester, AdminTestRepo(), 30, width: 320, scale: 2);
      await _clearUntil(tester);

      await _save(tester);

      expect(find.text(_endMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
