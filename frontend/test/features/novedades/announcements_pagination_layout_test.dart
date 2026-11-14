import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_page.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:agenda_medica/features/novedades/screens/announcements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

class _Session extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    role: UserRole.socio,
    accessToken: 'test-session',
  );
}

class _News extends FakeAnnouncementsRepository {
  _News({int count = 23})
    : items = [
        for (var id = 1; id <= count; id++)
          Announcement(
            id: id,
            title: 'Novedad $id',
            publishedAt: DateTime.utc(2026, 11, 1),
          ),
      ];

  final List<Announcement> items;
  final requestedPages = <int>[];

  @override
  Future<AnnouncementPage> list({int page = 0}) async {
    requestedPages.add(page);
    return AnnouncementPage(
      items: items.skip(page * 10).take(10).toList(),
      page: page,
      total: items.length,
    );
  }
}

final _previous = find.widgetWithText(OutlinedButton, 'Anterior');
final _next = find.widgetWithText(OutlinedButton, 'Siguiente');

Future<void> _showPagination(WidgetTester tester) async {
  await tester.ensureVisible(_next);
  await tester.pumpAndSettle();
}

Future<void> _pumpList(
  WidgetTester tester,
  _News repository, {
  required double width,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        announcementsRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AnnouncementsScreen(role: UserRole.socio),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _showPagination(tester);
}

void _expectControls(
  WidgetTester tester, {
  required int page,
  required bool previousEnabled,
  required bool nextEnabled,
}) {
  expect(find.text('Página $page'), findsOneWidget);
  expect(_previous, findsOneWidget);
  expect(_next, findsOneWidget);
  expect(
    tester.widget<OutlinedButton>(_previous).onPressed != null,
    previousEnabled,
  );
  expect(tester.widget<OutlinedButton>(_next).onPressed != null, nextEnabled);
}

void _expectLayout(WidgetTester tester, {required bool narrow, int page = 1}) {
  final previous = tester.getRect(_previous);
  final next = tester.getRect(_next);
  final label = tester.getRect(find.text('Página $page'));

  // Tolerancia de un píxel para redondeos, sin fijar posiciones absolutas.
  expect(previous.center.dy, closeTo(next.center.dy, 1));
  expect(previous.right, lessThan(next.left));
  if (narrow) {
    expect(label.bottom, lessThan(previous.top));
    expect(label.bottom, lessThan(next.top));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(label.center.dx, closeTo(screen.center.dx, 1));
  } else {
    expect(label.center.dy, closeTo(previous.center.dy, 1));
    expect(previous.right, lessThan(label.left));
    expect(label.right, lessThan(next.left));
  }
}

Future<void> _tapControl(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  await _showPagination(tester);
}

void main() {
  setUpAll(loadRoboto);

  group('bordes de paginación y texto grande', () {
    void expectVisibleControls(WidgetTester tester) {
      _expectControls(
        tester,
        page: 1,
        previousEnabled: false,
        nextEnabled: true,
      );
      final screen = tester.getRect(find.byType(Scaffold));
      final rects = [
        tester.getRect(_previous),
        tester.getRect(find.text('Página 1')),
        tester.getRect(_next),
      ];
      for (final rect in rects) {
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
        expect(rect.left, greaterThanOrEqualTo(screen.left));
        expect(rect.right, lessThanOrEqualTo(screen.right));
        expect(rect.top, greaterThanOrEqualTo(screen.top));
        expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse);
        }
      }
      expect(tester.takeException(), isNull);
    }

    for (final width in [340.0, 351.0]) {
      testWidgets('a $width px muestra el diseño compacto sin desbordes', (
        tester,
      ) async {
        await _pumpList(tester, _News(), width: width);

        _expectLayout(tester, narrow: true);
        expectVisibleControls(tester);
      });
    }

    testWidgets('a 352 px conserva los tres controles en una fila', (
      tester,
    ) async {
      await _pumpList(tester, _News(), width: 352);

      _expectLayout(tester, narrow: false);
      expectVisibleControls(tester);
    });

    // El caso 320 px con escala 2 ya está cubierto por los tests originales.
    for (final (width, scale) in [(340.0, 2.0), (320.0, 3.0), (340.0, 3.0)]) {
      testWidgets(
        'a $width px con texto x$scale los controles son visibles y no se solapan',
        (tester) async {
          await _pumpList(tester, _News(), width: width, scale: scale);

          expectVisibleControls(tester);
        },
      );
    }
  });

  testWidgets('a 320 px centra Página arriba y alinea los botones debajo', (
    tester,
  ) async {
    await _pumpList(tester, _News(), width: 320);

    _expectControls(tester, page: 1, previousEnabled: false, nextEnabled: true);
    _expectLayout(tester, narrow: true);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 600.0]) {
    testWidgets(
      'a $width px conserva Anterior, Página y Siguiente en una fila',
      (tester) async {
        await _pumpList(tester, _News(), width: width);

        _expectControls(
          tester,
          page: 1,
          previousEnabled: false,
          nextEnabled: true,
        );
        _expectLayout(tester, narrow: false);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [320.0, 360.0]) {
    testWidgets('a $width px con texto al doble los controles no desbordan', (
      tester,
    ) async {
      await _pumpList(tester, _News(), width: width, scale: 2);

      _expectControls(
        tester,
        page: 1,
        previousEnabled: false,
        nextEnabled: true,
      );
      final screen = tester.getRect(find.byType(Scaffold));
      final rects = [
        tester.getRect(_previous),
        tester.getRect(find.text('Página 1')),
        tester.getRect(_next),
      ];
      for (final rect in rects) {
        expect(rect.left, greaterThanOrEqualTo(screen.left));
        expect(rect.right, lessThanOrEqualTo(screen.right));
        expect(rect.top, greaterThanOrEqualTo(screen.top));
        expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
      }
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse);
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a $width px mantiene los estados al avanzar y retroceder', (
      tester,
    ) async {
      final repository = _News();
      await _pumpList(tester, repository, width: width);
      _expectControls(
        tester,
        page: 1,
        previousEnabled: false,
        nextEnabled: true,
      );

      await _tapControl(tester, _next);
      _expectControls(
        tester,
        page: 2,
        previousEnabled: true,
        nextEnabled: true,
      );
      expect(find.text('Novedad 11'), findsOneWidget);

      await _tapControl(tester, _next);
      _expectControls(
        tester,
        page: 3,
        previousEnabled: true,
        nextEnabled: false,
      );
      expect(find.text('Novedad 21'), findsOneWidget);

      await _tapControl(tester, _previous);
      _expectControls(
        tester,
        page: 2,
        previousEnabled: true,
        nextEnabled: true,
      );

      await _tapControl(tester, _previous);
      _expectControls(
        tester,
        page: 1,
        previousEnabled: false,
        nextEnabled: true,
      );
      expect(find.text('Novedad 1'), findsOneWidget);
      expect(repository.requestedPages, [0, 1, 2, 1, 0]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a 320 px sin novedades conserva ambos botones deshabilitados', (
    tester,
  ) async {
    await _pumpList(tester, _News(count: 0), width: 320);

    _expectControls(
      tester,
      page: 1,
      previousEnabled: false,
      nextEnabled: false,
    );
    expect(tester.takeException(), isNull);
  });
}
