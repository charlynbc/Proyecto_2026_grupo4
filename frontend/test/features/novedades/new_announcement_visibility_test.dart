import 'package:agenda_medica/core/config/app_locale.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:agenda_medica/features/novedades/screens/new_announcement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';

// Los mensajes se escriben a mano, no con constantes del código.
const _endMessage =
    'La fecha de fin es obligatoria y debe ser posterior al inicio';

// "Ahora" fijo: 14/11/2026 12:00 en Uruguay (15:00 UTC).
final _now = DateTime.utc(2026, 11, 14, 15);

class _Admin extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    role: UserRole.administrador,
    accessToken: 'test-session',
  );
}

class _Repo extends FakeAnnouncementsRepository {
  final drafts = <AnnouncementDraft>[];
  ApiException? error;

  @override
  Future<void> publish(AnnouncementDraft draft) async {
    drafts.add(draft);
    if (error != null) throw error!;
  }
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

const _fromDate = 'Visible desde: fecha';
const _fromTime = 'Visible desde: hora';
const _untilDate = 'Visible hasta: fecha';
const _untilTime = 'Visible hasta: hora';

String _textOf(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(_field(label)).controller!.text;

Future<_Repo> _pump(
  WidgetTester tester, {
  double width = 900,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  final router = GoRouter(
    initialLocation: '/nueva',
    routes: [
      GoRoute(
        path: '/nueva',
        builder: (context, state) => const NewAnnouncementScreen(),
      ),
      GoRoute(
        path: '/admin/cartelera',
        builder: (context, state) => const Text('Lista de novedades'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_Admin.new),
        announcementClockProvider.overrideWithValue(() => _now),
        announcementsRepositoryProvider.overrideWith((ref) async => repo),
      ],
      child: MaterialApp.router(
        theme: appTheme,
        locale: kAppLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kLocalizationsDelegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _fillContent(WidgetTester tester) async {
  await tester.enterText(_field('Título'), 'Campaña de vacunación');
  await tester.enterText(_field('Texto de la novedad'), 'Contenido');
}

Future<void> _publish(WidgetTester tester) async {
  final publish = find.widgetWithText(FilledButton, 'Publicar');
  await tester.ensureVisible(publish);
  await tester.tap(publish);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra los cuatro campos y explica que el fin es exclusivo', (
    tester,
  ) async {
    await _pump(tester);

    for (final label in [_fromDate, _fromTime, _untilDate, _untilTime]) {
      expect(_field(label), findsOneWidget, reason: label);
    }
    expect(
      find.textContaining('se deja de ver en el minuto exacto del fin'),
      findsOneWidget,
    );
  });

  testWidgets('al escribir la fecha de inicio propone 00:00', (tester) async {
    await _pump(tester);

    await tester.enterText(_field(_fromDate), '20/11/2026');
    await tester.pump();

    expect(_textOf(tester, _fromTime), '00:00');
  });

  testWidgets('al escribir la fecha de fin propone 23:59', (tester) async {
    await _pump(tester);

    await tester.enterText(_field(_untilDate), '25/11/2026');
    await tester.pump();

    expect(_textOf(tester, _untilTime), '23:59');
  });

  testWidgets('no pisa una hora que ya estaba escrita', (tester) async {
    await _pump(tester);

    await tester.enterText(_field(_untilTime), '18:30');
    await tester.enterText(_field(_untilDate), '25/11/2026');
    await tester.pump();

    expect(_textOf(tester, _untilTime), '18:30');
  });

  testWidgets('sin fecha de fin no se publica y muestra el mensaje', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await _fillContent(tester);

    await _publish(tester);

    expect(repo.drafts, isEmpty);
    expect(find.text(_endMessage), findsOneWidget);
  });

  testWidgets('fin igual al inicio no se publica', (tester) async {
    final repo = await _pump(tester);
    await _fillContent(tester);
    await tester.enterText(_field(_fromDate), '20/11/2026');
    await tester.enterText(_field(_fromTime), '10:00');
    await tester.enterText(_field(_untilDate), '20/11/2026');
    await tester.enterText(_field(_untilTime), '10:00');

    await _publish(tester);

    expect(repo.drafts, isEmpty);
    expect(find.text(_endMessage), findsOneWidget);
  });

  testWidgets('fin anterior al inicio no se publica', (tester) async {
    final repo = await _pump(tester);
    await _fillContent(tester);
    await tester.enterText(_field(_fromDate), '20/11/2026');
    await tester.enterText(_field(_untilDate), '19/11/2026');

    await _publish(tester);

    expect(repo.drafts, isEmpty);
    expect(find.text(_endMessage), findsOneWidget);
  });

  testWidgets('sin inicio, un fin que ya pasó no se publica', (tester) async {
    final repo = await _pump(tester);
    await _fillContent(tester);
    await tester.enterText(_field(_untilDate), '14/11/2026');
    await tester.enterText(_field(_untilTime), '11:59');

    await _publish(tester);

    expect(repo.drafts, isEmpty);
    expect(find.text(_endMessage), findsOneWidget);
  });

  testWidgets('con inicio y fin válidos publica con las horas de Uruguay', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await _fillContent(tester);
    await tester.enterText(_field(_fromDate), '20/11/2026');
    await tester.enterText(_field(_untilDate), '25/11/2026');

    await _publish(tester);

    // 20/11 00:00 -03:00 = 03:00 UTC; 25/11 23:59 -03:00 = 26/11 02:59 UTC.
    expect(repo.drafts.single.visibleFrom, DateTime.utc(2026, 11, 20, 3));
    expect(repo.drafts.single.visibleUntil, DateTime.utc(2026, 11, 26, 2, 59));
    expect(find.text('Lista de novedades'), findsOneWidget);
  });

  testWidgets('sin inicio publica solo con fin', (tester) async {
    final repo = await _pump(tester);
    await _fillContent(tester);
    await tester.enterText(_field(_untilDate), '15/11/2026');
    await tester.enterText(_field(_untilTime), '18:30');

    await _publish(tester);

    expect(repo.drafts.single.visibleFrom, isNull);
    // 15/11 18:30 -03:00 = 21:30 UTC.
    expect(repo.drafts.single.visibleUntil, DateTime.utc(2026, 11, 15, 21, 30));
  });

  testWidgets('una hora sin fecha pide la fecha', (tester) async {
    final repo = await _pump(tester);
    await _fillContent(tester);
    await tester.enterText(_field(_untilDate), '25/11/2026');
    await tester.enterText(_field(_fromTime), '10:00');

    await _publish(tester);

    expect(repo.drafts, isEmpty);
    expect(find.text('Elegí la fecha.'), findsOneWidget);
  });

  testWidgets('una fecha sin hora pide la hora', (tester) async {
    final repo = await _pump(tester);
    await _fillContent(tester);
    await tester.enterText(_field(_untilDate), '25/11/2026');
    await tester.pump();
    await tester.tap(find.byTooltip('Borrar la hora'));
    await tester.pump();

    await _publish(tester);

    expect(repo.drafts, isEmpty);
    expect(find.text('Elegí la hora.'), findsOneWidget);
  });

  testWidgets('si el servidor responde 400 muestra su mensaje', (tester) async {
    final repo = await _pump(tester);
    repo.error = const ApiException('Mensaje del servidor de prueba');
    await _fillContent(tester);
    await tester.enterText(_field(_untilDate), '25/11/2026');

    await _publish(tester);

    expect(repo.drafts, hasLength(1));
    expect(find.text('Mensaje del servidor de prueba'), findsOneWidget);
  });

  group('a 320 px de ancho con texto al doble (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('los cuatro campos entran sin desbordar', (tester) async {
      await _pump(tester, width: 320, scale: 2);

      expect(tester.takeException(), isNull);
      for (final label in [_fromDate, _fromTime, _untilDate, _untilTime]) {
        await tester.ensureVisible(_field(label));
        final rect = tester.getRect(_field(label));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('con errores a la vista tampoco desborda', (tester) async {
      await _pump(tester, width: 320, scale: 2);
      await _fillContent(tester);

      await _publish(tester);

      expect(find.text(_endMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
