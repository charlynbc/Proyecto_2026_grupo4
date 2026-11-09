import 'dart:async';
import 'dart:convert';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/models/announcement_page.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:agenda_medica/features/novedades/screens/new_announcement_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import '../cuenta/account_test_support.dart' show RecordingAccountRepository;

class _Session extends SessionNotifier {
  _Session(this.role);

  final UserRole role;

  @override
  SessionState build() => SessionState(
    status: SessionStatus.authenticated,
    role: role,
    accessToken: 'test-session',
  );
}

class _News extends FakeAnnouncementsRepository {
  List<Announcement> items = [
    for (var id = 23; id > 0; id--)
      Announcement(
        id: id,
        title: 'Novedad $id',
        summary: 'Descripción $id',
        publishedAt: DateTime.utc(2026, 11, 1),
      ),
  ];
  final pages = <int>[];
  final details = <int>[];
  Object? error;
  Completer<AnnouncementPage>? pending;
  final drafts = <AnnouncementDraft>[];
  ApiException? publishError;

  @override
  Future<void> publish(AnnouncementDraft draft) async {
    drafts.add(draft);
    if (publishError != null) throw publishError!;
    items.insert(
      0,
      Announcement(
        id: 24,
        title: draft.title,
        summary: draft.summary,
        publishedAt: DateTime.utc(2026, 11, 9),
      ),
    );
  }

  @override
  Future<List<Announcement>> latest() async => items.take(5).toList();

  @override
  Future<AnnouncementDetail> detail(int id) async {
    details.add(id);
    return AnnouncementDetail(
      id: id,
      title: 'Detalle $id',
      text: '**Contenido** completo de la novedad.',
      publishedAt: DateTime.utc(2026, 11, 1),
    );
  }

  @override
  Future<AnnouncementPage> list({int page = 0}) async {
    pages.add(page);
    if (error != null) throw error!;
    return pending?.future ??
        AnnouncementPage(
          items: items.skip(page * 10).take(10).toList(),
          page: page,
          total: items.length,
        );
  }
}

Future<ProviderContainer> _pumpList(
  WidgetTester tester,
  _News repo, {
  double width = 1280,
  double scale = 1,
  UserRole role = UserRole.socio,
  List<AnnouncementImageUpload> images = const [],
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(() => _Session(role)),
      announcementImagePickerProvider.overrideWithValue((_) async => images),
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
  final router = container.read(goRouterProvider)..go(role.announcementsPath);
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

Finder _rows() => find.byWidgetPredicate(
  (w) => w is Card && w.key.toString().contains('announcement-row-'),
);

void main() {
  for (final role in UserRole.values) {
    testWidgets('${role.name} consulta y solo el administrador puede crear', (
      tester,
    ) async {
      final repo = _News();
      final container = await _pumpList(tester, repo, role: role);
      expect(
        find.text('Crear nueva novedad'),
        role == UserRole.administrador ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('Novedad 23'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle 23'), findsOneWidget);
      expect(repo.details, [23]);
      await tester.tap(find.byTooltip('Volver a novedades'));
      await tester.pumpAndSettle();
      expect(locationOf(container), role.announcementsPath);
      if (role != UserRole.administrador) {
        await goTo(tester, container, '/admin/cartelera/nueva');
        expect(locationOf(container), role.homePath);
        expect(find.byType(NewAnnouncementScreen), findsNothing);
      }
      await unmountApp(tester);
      if (role == UserRole.medico) {
        container.invalidate(doctorAgendaControllerProvider);
      }
    });
  }

  testWidgets(
    'edita Markdown, conserva el borrador ante un rechazo y publica en página 1',
    (tester) async {
      final repo = _News()
        ..publishError = const ApiException('Servicio no disponible');
      final container = await _pumpList(
        tester,
        repo,
        role: UserRole.administrador,
      );
      final next = find.widgetWithText(OutlinedButton, 'Siguiente');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Página 2'), findsOneWidget);
      await tester.tap(find.text('Crear nueva novedad'));
      await tester.pumpAndSettle();
      final title = find.widgetWithText(TextFormField, 'Título');
      await tester.enterText(title, 'Jornada informativa');
      final body = find.widgetWithText(TextFormField, 'Texto de la novedad');
      await tester.enterText(body, 'Información');
      final controller = tester.widget<TextFormField>(body).controller!;
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
      await tester.tap(find.byTooltip('Negrita'));
      await tester.pumpAndSettle();
      expect(controller.text, '**Información**');
      await tester.tap(find.text('Vista previa'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);

      final publish = find.widgetWithText(FilledButton, 'Publicar');
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(find.text('Servicio no disponible'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(title).controller!.text,
        'Jornada informativa',
      );
      expect(repo.drafts.single.text, '**Información**');
      repo.publishError = null;
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(locationOf(container), '/admin/cartelera');
      expect(find.text('Página 1'), findsOneWidget);
      expect(find.text('Jornada informativa'), findsOneWidget);
      expect(find.text('Novedad publicada'), findsOneWidget);
    },
  );

  testWidgets('valida y cuenta el título sin sus espacios exteriores', (
    tester,
  ) async {
    final repo = _News();
    await _pumpList(tester, repo, role: UserRole.administrador);
    await tester.tap(find.text('Crear nueva novedad'));
    await tester.pumpAndSettle();
    final title = find.widgetWithText(TextFormField, 'Título');
    final publish = find.widgetWithText(FilledButton, 'Publicar');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Texto de la novedad'),
      'Contenido',
    );
    await tester.enterText(title, 'a' * 161);
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(find.text('El título admite hasta 160 caracteres.'), findsOneWidget);
    expect(repo.drafts, isEmpty);

    final validTitle = 'a' * 160;
    await tester.enterText(title, '  $validTitle  ');
    await tester.pumpAndSettle();
    expect(find.text('160/160'), findsOneWidget);
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(repo.drafts.single.title, validTitle);
  });

  testWidgets(
    'exige contenido y permite publicar solo imágenes con portada elegida',
    (tester) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2k8AAAAASUVORK5CYII=',
      );
      final repo = _News();
      await _pumpList(
        tester,
        repo,
        role: UserRole.administrador,
        images: [
          AnnouncementImageUpload(
            name: 'primera.png',
            bytes: bytes,
            subtype: 'png',
          ),
          AnnouncementImageUpload(
            name: 'segunda.png',
            bytes: bytes,
            subtype: 'png',
          ),
        ],
      );
      await tester.tap(find.text('Crear nueva novedad'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título'),
        'Cartel de la jornada',
      );
      final publish = find.widgetWithText(FilledButton, 'Publicar');
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(find.text('Agregá texto o al menos una imagen.'), findsOneWidget);
      expect(repo.drafts, isEmpty);
      final add = find.text('Agregar imágenes');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      final up = find.byTooltip('Subir imagen segunda.png');
      await tester.ensureVisible(up);
      await tester.tap(up);
      await tester.pumpAndSettle();
      await tester.ensureVisible(publish);
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(repo.drafts.single.text, isNull);
      expect(repo.drafts.single.images.map((image) => image.name), [
        'segunda.png',
        'primera.png',
      ]);
      expect(find.text('Cartel de la jornada'), findsOneWidget);
    },
  );

  setUpAll(loadRoboto);

  testWidgets(
    'lista muestra diez, título y descripción a la derecha de la imagen',
    (tester) async {
      final repo = _News();
      await _pumpList(tester, repo);
      expect(_rows(), findsNWidgets(10));
      expect(find.text('Novedad 23'), findsOneWidget);
      expect(find.text('Novedad 13'), findsNothing);
      final cover = find.byKey(
        const ValueKey('announcement-cover-placeholder-23'),
      );
      final title = find.text('Novedad 23');
      final summary = find.text('Descripción 23');
      expect(
        tester.getTopLeft(title).dx,
        greaterThan(tester.getTopRight(cover).dx),
      );
      expect(tester.getTopLeft(summary).dx, tester.getTopLeft(title).dx);
      expect(
        tester.getTopLeft(summary).dy,
        greaterThan(tester.getBottomLeft(title).dy),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(repo.pages, [0]);
    },
  );

  testWidgets(
    'siguiente muestra otras diez y la última solo tres; anterior vuelve',
    (tester) async {
      final repo = _News();
      await _pumpList(tester, repo);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Anterior'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Siguiente'));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(_rows(), findsNWidgets(10));
      expect(find.text('Novedad 13'), findsOneWidget);
      expect(find.text('Novedad 23'), findsNothing);
      expect(find.text('Página 2'), findsOneWidget);
      await tester.ensureVisible(find.text('Siguiente'));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(_rows(), findsNWidgets(3));
      expect(find.text('Novedad 3'), findsOneWidget);
      expect(find.text('Página 3'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Siguiente'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Anterior'));
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Página 2'), findsOneWidget);
      expect(repo.pages, [0, 1, 2, 1]);
    },
  );

  testWidgets(
    'una fila de página dos abre su detalle y vuelve conservando página y posición',
    (tester) async {
      final repo = _News();
      final container = await _pumpList(tester, repo);
      await tester.ensureVisible(find.text('Siguiente'));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('announcement-row-10'));
      await tester.ensureVisible(row);
      final before = tester.getTopLeft(row).dy;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(locationOf(container), '/socio/cartelera/10?desde=cartelera');
      expect(find.text('Detalle 10'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver a novedades'));
      await tester.pumpAndSettle();
      expect(locationOf(container), '/socio/cartelera');
      expect(find.text('Página 2'), findsOneWidget);
      expect(tester.getTopLeft(row).dy, closeTo(before, 1));
      expect(repo.pages, [0, 1]);
      expect(repo.details, [10]);
    },
  );

  testWidgets('portada abre el mismo detalle que el texto', (tester) async {
    final repo = _News();
    await _pumpList(tester, repo);
    await tester.tap(
      find.byKey(const ValueKey('announcement-cover-placeholder-23')),
    );
    await tester.pumpAndSettle();
    expect(repo.details, [23]);
    expect(find.text('Detalle 23'), findsOneWidget);
  });

  testWidgets('lista vacía deshabilita avanzar', (tester) async {
    await _pumpList(tester, _News()..items = []);
    expect(find.text('Todavía no hay novedades publicadas.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Siguiente'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('carga y error permiten reintentar sin peticiones automáticas', (
    tester,
  ) async {
    final repo = _News()..pending = Completer<AnnouncementPage>();
    await _pumpList(tester, repo);
    expect(find.text('Cargando novedades…'), findsOneWidget);
    repo.pending!.completeError(
      const ApiException('Almacenamiento no disponible'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Almacenamiento no disponible'), findsOneWidget);
    expect(repo.pages, [0]);
    repo.pending = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(_rows(), findsNWidgets(10));
    expect(repo.pages, [0, 0]);
  });

  testWidgets('fallo de segunda página permite volver a la anterior', (
    tester,
  ) async {
    final repo = _News();
    await _pumpList(tester, repo);
    repo.error = const ApiException();
    await tester.ensureVisible(find.text('Siguiente'));
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    repo.error = null;
    await tester.tap(find.text('Volver a la página anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Página 1'), findsOneWidget);
    expect(_rows(), findsNWidgets(10));
  });

  testWidgets('actualizar renueva portadas consultando la misma página', (
    tester,
  ) async {
    final repo = _News();
    await _pumpList(tester, repo);
    await tester.tap(find.text('Actualizar novedades'));
    await tester.pumpAndSettle();
    expect(repo.pages, [0, 0]);
  });

  for (final width in [320.0, 600.0, 1440.0]) {
    testWidgets(
      'lista a $width px con texto ampliado, título largo y portada fallida',
      (tester) async {
        final repo = _News()
          ..items = [
            Announcement(
              id: 1,
              title: List.filled(8, 'Título largo').join(' '),
              summary: List.filled(10, 'Descripción extensa').join(' '),
              coverUrl: 'https://example.invalid/portada.jpg',
              publishedAt: DateTime.utc(2026, 11, 1),
            ),
          ];
        await _pumpList(tester, repo, width: width, scale: 2);
        expect(
          find.byKey(const ValueKey('announcement-cover-placeholder-1')),
          findsOneWidget,
        );
        expect(
          find.byType(width < 600 ? NavigationBar : NavigationRail),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Siguiente'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
