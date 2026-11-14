import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/adaptive_nav_bar.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_page.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/announcements_repository.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:agenda_medica/features/novedades/widgets/announcement_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import '../cuenta/account_test_support.dart' show RecordingAccountRepository;

class _Session extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    role: UserRole.socio,
    accessToken: 'test-session',
  );

  void expire() =>
      state = const SessionState(status: SessionStatus.unauthenticated);
}

class _News extends FakeAnnouncementsRepository {
  @override
  Future<AnnouncementPage> list({int page = 0}) async =>
      AnnouncementPage(items: [], page: page, total: 0);

  AnnouncementDetail value = makeDetail();
  Object? error;
  Completer<AnnouncementDetail>? pending;
  final calls = <int>[];

  @override
  Future<List<Announcement>> latest() async => [];

  @override
  Future<AnnouncementDetail> detail(int id) async {
    calls.add(id);
    if (error != null) throw error!;
    return pending?.future ?? value;
  }
}

AnnouncementDetail makeDetail({
  String? title = 'Campaña de vacunación',
  String? summary = 'Comienza el lunes',
  String? text =
      '**Vacunarse** ayuda a prevenir la gripe.\n\n- Una lista\n- Otro punto',
  int images = 0,
}) => AnnouncementDetail(
  id: 42,
  title: title,
  summary: summary,
  text: text,
  publishedAt: DateTime.utc(2026, 11, 3, 12),
  images: [
    for (var i = 0; i < images; i++)
      AnnouncementImage(
        id: i + 1,
        order: i,
        url: 'https://example.invalid/imagen-$i',
      ),
  ],
);

Future<ProviderContainer> _pumpDetail(
  WidgetTester tester,
  _News repo, {
  String path = '/socio/cartelera/42',
  double width = 1280,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_Session.new),
      accountRepositoryProvider.overrideWith(
        (ref) async => RecordingAccountRepository(),
      ),
      announcementsRepositoryProvider.overrideWith((ref) async => repo),
    ],
  );
  addTearDown(() async {
    await unmountApp(tester);
    container.dispose();
  });
  final router = container.read(goRouterProvider)..go(path);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  if (repo.pending == null) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }
  return container;
}

void main() {
  setUpAll(loadRoboto);

  testWidgets(
    'detalle directo usa el id, Markdown y controles de sesión; vuelve sin historial',
    (tester) async {
      final repo = _News();
      final container = await _pumpDetail(tester, repo);
      expect(repo.calls, [42]);
      expect(find.text('Campaña de vacunación'), findsOneWidget);
      expect(find.text('Comienza el lunes'), findsOneWidget);
      expect(find.text('Publicado el 03/11/2026'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
      final spans = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.textSpan?.toPlainText() ?? w.data ?? '')
          .join(' ');
      expect(spans, contains('Vacunarse ayuda a prevenir la gripe.'));
      expect(spans, isNot(contains('**Vacunarse**')));
      expect(find.byType(AnnouncementGallery), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byTooltip('Mi cuenta'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver al Inicio'));
      await tester.pumpAndSettle();
      expect(locationOf(container), '/socio/inicio');
      expect(find.byType(NavigationRail), findsNothing);
    },
  );

  testWidgets('carga muestra estado y luego contenido', (tester) async {
    final repo = _News()..pending = Completer<AnnouncementDetail>();
    await _pumpDetail(tester, repo);
    expect(find.text('Cargando novedad…'), findsOneWidget);
    repo.pending!.complete(makeDetail());
    await tester.pumpAndSettle();
    expect(find.text('Campaña de vacunación'), findsOneWidget);
    expect(find.text('Cargando novedad…'), findsNothing);
  });

  testWidgets('error 503 permite un reintento explícito', (tester) async {
    final repo = _News()
      ..error = const ApiException('Almacenamiento no disponible');
    await _pumpDetail(tester, repo);
    expect(find.text('Almacenamiento no disponible'), findsOneWidget);
    expect(repo.calls, [42]);
    repo.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(repo.calls, [42, 42]);
    expect(find.text('Campaña de vacunación'), findsOneWidget);
  });

  testWidgets('404 no ofrece reintento y mantiene regreso', (tester) async {
    await _pumpDetail(
      tester,
      _News()..error = const AnnouncementNotFoundException(),
    );
    expect(find.text('No encontramos esta novedad.'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.byTooltip('Volver al Inicio'), findsOneWidget);
  });

  for (final id in ['abc', '0', '-1', '1.5', '99999999999999999999999']) {
    testWidgets('identificador $id no consulta la API', (tester) async {
      final repo = _News();
      await _pumpDetail(tester, repo, path: '/socio/cartelera/$id');
      expect(repo.calls, isEmpty);
      expect(find.text('No encontramos esta novedad.'), findsOneWidget);
    });
  }

  testWidgets('sesión vencida usa la redirección existente', (tester) async {
    final container = await _pumpDetail(tester, _News());
    (container.read(sessionProvider.notifier) as _Session).expire();
    await tester.pumpAndSettle();
    expect(locationOf(container), '/login');
    expect(find.text('Campaña de vacunación'), findsNothing);
  });

  testWidgets(
    'una imagen fallida conserva texto y renueva por API sin bucles',
    (tester) async {
      final repo = _News()..value = makeDetail(images: 1);
      await _pumpDetail(tester, repo);
      expect(find.byTooltip('Imagen siguiente'), findsNothing);
      expect(find.text('No pudimos cargar esta imagen.'), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
      repo.pending = Completer<AnnouncementDetail>();
      await tester.tap(find.text('Volver a cargar imágenes'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(MarkdownBody), findsOneWidget);
      repo.pending!.complete(makeDetail(images: 1));
      await tester.pumpAndSettle();
      expect(repo.calls, [42, 42]);
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.byTooltip('Volver al Inicio'), findsOneWidget);
    },
  );

  testWidgets('galería recorre imágenes de la misma novedad', (tester) async {
    final repo = _News()..value = makeDetail(images: 3, text: null);
    await _pumpDetail(tester, repo);
    expect(find.byType(MarkdownBody), findsNothing);
    await tester.ensureVisible(find.byTooltip('Imagen siguiente'));
    await tester.tap(find.byTooltip('Imagen siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Imagen 2 de 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Imagen 3 de 3'));
    await tester.pumpAndSettle();
    expect(find.text('Imagen 3 de 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Imagen anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Imagen 2 de 3'), findsOneWidget);
    expect(repo.calls, [42]);
  });

  for (final width in [320.0, 600.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('a $width px y texto x$scale admite título largo y galería', (
        tester,
      ) async {
        await _pumpDetail(
          tester,
          _News()
            ..value = makeDetail(
              title: List.filled(15, 'Título largo').join(' '),
              images: 3,
            ),
          width: width,
          scale: scale,
        );
        expect(
          find.byType(width < 600 ? AdaptiveNavBar : NavigationRail),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byType(MarkdownBody));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('título antiguo, resumen y texto ausentes no se inventan', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      _News()
        ..value = makeDetail(title: null, summary: null, text: null, images: 1),
    );
    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.text('Novedad de la mutualista'), findsNothing);
    expect(find.text('Publicado el 03/11/2026'), findsOneWidget);
    expect(find.byType(AnnouncementGallery), findsOneWidget);
  });
}
