import 'dart:convert';

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

import '../../helpers/load_roboto.dart';

const _contentError = 'Agregá texto o al menos una imagen.';
const _endError =
    'La fecha de fin es obligatoria y debe ser posterior al inicio';
const _serverError = 'No se pudo publicar la novedad de prueba.';

class _Admin extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    role: UserRole.administrador,
    accessToken: 'test-session',
  );
}

class _Repository extends FakeAnnouncementsRepository {
  final drafts = <AnnouncementDraft>[];

  @override
  Future<void> publish(AnnouncementDraft draft) async {
    drafts.add(draft);
    throw const ApiException(_serverError);
  }
}

AnnouncementImageUpload _image(String name) => AnnouncementImageUpload(
  name: name,
  subtype: 'png',
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2k8AAAAASUVORK5CYII=',
  ),
);

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<_Repository> _pump(
  WidgetTester tester, {
  Future<List<AnnouncementImageUpload>> Function(int)? picker,
  double width = 900,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _Repository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(_Admin.new),
        announcementsRepositoryProvider.overrideWith((ref) async => repository),
        announcementClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 11, 20, 15),
        ),
        announcementImagePickerProvider.overrideWithValue(
          picker ?? (_) async => [_image('primera.png'), _image('segunda.png')],
        ),
      ],
      child: MaterialApp(
        theme: appTheme,
        locale: kAppLocale,
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kLocalizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const NewAnnouncementScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _publish(WidgetTester tester) =>
    _tap(tester, find.widgetWithText(FilledButton, 'Publicar'));

Future<void> _contentFailure(WidgetTester tester) async {
  await tester.enterText(_field('Título'), 'Jornada de prevención');
  await _publish(tester);
  expect(find.text(_contentError), findsOneWidget);
}

Future<void> _serverFailure(WidgetTester tester) async {
  await tester.enterText(_field('Título'), 'Jornada de prevención');
  await tester.enterText(_field('Texto de la novedad'), 'Atención el viernes.');
  await tester.enterText(_field('Visible hasta: fecha'), '30/11/2026');
  await _publish(tester);
  expect(find.text(_serverError), findsOneWidget);
}

void main() {
  setUpAll(loadRoboto);

  testWidgets(
    'revalida el título tras escribir sin confundir el error del campo',
    (tester) async {
      await _pump(tester);
      await _publish(tester);
      expect(find.text('Ingresá el título.'), findsOneWidget);
      // Sin texto ni imágenes, el contenido también se marca en el mismo toque.
      expect(find.text(_contentError), findsOneWidget);
      await _tap(tester, _field('Título'));
      expect(find.text('Ingresá el título.'), findsOneWidget);
      await tester.enterText(_field('Título'), 'Jornada de prevención');
      await tester.pumpAndSettle();
      expect(find.text('Ingresá el título.'), findsNothing);
      await tester.enterText(_field('Título'), '');
      await _publish(tester);
      expect(find.text('Ingresá el título.'), findsOneWidget);
    },
  );

  for (final (label, value) in [
    ('Título', 'Jornada de salud'),
    ('Resumen (opcional)', 'Inscripción abierta'),
    ('Texto de la novedad', '   '),
  ]) {
    testWidgets('limpia publicación al cambiar $label y vuelve a validar', (
      tester,
    ) async {
      final repository = await _pump(tester);
      await _contentFailure(tester);
      await tester.enterText(_field(label), value);
      await tester.pumpAndSettle();
      expect(find.text(_contentError), findsNothing);
      await _publish(tester);
      expect(find.text(_contentError), findsOneWidget);
      expect(repository.drafts, isEmpty);
    });
  }

  testWidgets('limpia publicación al agregar imágenes', (tester) async {
    await _pump(tester);
    await _contentFailure(tester);
    await _tap(tester, find.text('Agregar imágenes'));
    expect(find.text('primera.png'), findsOneWidget);
    expect(find.text('segunda.png'), findsOneWidget);
    expect(find.text(_contentError), findsNothing);
  });

  for (final operation in ['quitar', 'reordenar']) {
    testWidgets('limpia publicación al $operation imágenes', (tester) async {
      final repository = await _pump(tester);
      await _tap(tester, find.text('Agregar imágenes'));
      await _serverFailure(tester);
      expect(repository.drafts, hasLength(1));
      await _tap(
        tester,
        find.byTooltip(
          operation == 'quitar'
              ? 'Quitar imagen primera.png'
              : 'Subir imagen segunda.png',
        ),
      );
      expect(find.text(_serverError), findsNothing);
      await _publish(tester);
      expect(find.text(_serverError), findsOneWidget);
      expect(repository.drafts, hasLength(2));
      expect(
        repository.drafts.last.images.map((image) => image.name).toList(),
        operation == 'quitar'
            ? ['segunda.png']
            : ['segunda.png', 'primera.png'],
      );
    });
  }

  testWidgets(
    'limpia el error del servidor al editar y lo muestra en otro intento',
    (tester) async {
      final repository = await _pump(tester);
      await _serverFailure(tester);
      await tester.enterText(_field('Título'), 'Jornada actualizada');
      await tester.pumpAndSettle();
      expect(find.text(_serverError), findsNothing);
      await _publish(tester);
      expect(find.text(_serverError), findsOneWidget);
      expect(repository.drafts, hasLength(2));
      expect(repository.drafts.last.title, 'Jornada actualizada');
    },
  );

  testWidgets(
    'conserva el error al enfocar, mover el cursor y no cambiar texto',
    (tester) async {
      await _pump(tester);
      await _contentFailure(tester);
      for (final label in [
        'Título',
        'Resumen (opcional)',
        'Texto de la novedad',
      ]) {
        await _tap(tester, _field(label));
        expect(find.text(_contentError), findsOneWidget);
        final controller = tester
            .widget<TextFormField>(_field(label))
            .controller!;
        controller.selection = const TextSelection.collapsed(offset: 0);
        await tester.pumpAndSettle();
        expect(find.text(_contentError), findsOneWidget);
        await tester.enterText(_field(label), controller.text);
        await tester.pumpAndSettle();
        expect(find.text(_contentError), findsOneWidget);
      }
      await _tap(tester, find.text('Vista previa'));
      expect(find.text(_contentError), findsOneWidget);
    },
  );

  testWidgets(
    'cancelar o fallar al elegir imágenes conserva el error de publicación',
    (tester) async {
      var attempts = 0;
      await _pump(
        tester,
        picker: (_) async {
          attempts++;
          if (attempts == 1) return [];
          throw const ApiException('No se pudo leer la imagen.');
        },
      );
      await _contentFailure(tester);
      await _tap(tester, find.text('Agregar imágenes'));
      expect(find.text(_contentError), findsOneWidget);
      await _tap(tester, find.text('Agregar imágenes'));
      expect(find.text('No se pudo leer la imagen.'), findsOneWidget);
      expect(find.text(_contentError), findsOneWidget);
      expect(attempts, 2);
    },
  );

  testWidgets(
    'el formato Markdown también limpia el error cuando cambia el texto',
    (tester) async {
      await _pump(tester);
      await _contentFailure(tester);
      await _tap(tester, find.byTooltip('Negrita'));
      expect(find.text(_contentError), findsNothing);
      expect(
        tester
            .widget<TextFormField>(_field('Texto de la novedad'))
            .controller!
            .text,
        isNotEmpty,
      );
    },
  );

  testWidgets('muestra a la vez el error de contenido y el de fecha de fin', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(_field('Título'), 'Prueba');
    await tester.enterText(_field('Texto de la novedad'), 'x');
    await _publish(tester);
    expect(find.text(_endError), findsOneWidget);
    expect(find.text(_contentError), findsNothing);
    await tester.enterText(_field('Texto de la novedad'), '');
    await _publish(tester);
    expect(find.text(_contentError), findsOneWidget);
    expect(find.text(_endError), findsOneWidget);
  });

  testWidgets(
    'elegir una fecha de inicio y borrarla muestra contenido y fin sin pedir '
    'la fecha',
    (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(_field('Título'), 'Prueba');
      await tester.enterText(_field('Visible desde: fecha'), '20/11/2026');
      await tester.pump();
      await tester.enterText(_field('Visible desde: fecha'), '');
      await tester.pump();
      await _publish(tester);
      expect(find.text(_contentError), findsOneWidget);
      expect(find.text(_endError), findsOneWidget);
      expect(find.text('Elegí la fecha.'), findsNothing);
      expect(repository.drafts, isEmpty);
    },
  );

  testWidgets(
    'una hora escrita sin fecha muestra a la vez la fecha, el contenido y el '
    'fin',
    (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(_field('Título'), 'Prueba');
      await tester.enterText(_field('Visible desde: hora'), '18:30');
      await _publish(tester);
      expect(find.text('Elegí la fecha.'), findsOneWidget);
      expect(find.text(_contentError), findsOneWidget);
      expect(find.text(_endError), findsOneWidget);
      expect(repository.drafts, isEmpty);
    },
  );

  testWidgets(
    'un fin con formato inválido muestra el error del campo y no el de fin '
    'obligatorio',
    (tester) async {
      final repository = await _pump(tester);
      // La fecha va primero: un campo con foco no marca un texto a medias.
      await tester.enterText(_field('Visible hasta: fecha'), '3/11');
      await tester.enterText(_field('Título'), 'Prueba');
      await tester.enterText(_field('Texto de la novedad'), 'x');
      await _publish(tester);
      expect(
        find.text('Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.'),
        findsOneWidget,
      );
      expect(find.text(_endError), findsNothing);
      expect(repository.drafts, isEmpty);
    },
  );

  testWidgets(
    'a 320 px con texto x2 caben a la vez los errores de campo, contenido y fin',
    (tester) async {
      await _pump(tester, width: 320, scale: 2);
      await tester.enterText(_field('Visible desde: hora'), '18:30');
      await _publish(tester);
      expect(find.text('Ingresá el título.'), findsOneWidget);
      expect(find.text('Elegí la fecha.'), findsOneWidget);
      expect(find.text(_contentError), findsOneWidget);
      expect(find.text(_endError), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sin contenido el error se limpia al escribir y vuelve al publicar de nuevo',
    (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(_field('Título'), 'Prueba');
      await _publish(tester);
      expect(find.text(_contentError), findsOneWidget);
      await tester.enterText(_field('Texto de la novedad'), 'x');
      await tester.pumpAndSettle();
      expect(find.text(_contentError), findsNothing);
      await tester.enterText(_field('Texto de la novedad'), '');
      await tester.pumpAndSettle();
      await _publish(tester);
      expect(find.text(_contentError), findsOneWidget);
      expect(repository.drafts, isEmpty);
    },
  );

  testWidgets(
    'una fecha inválida tras un error del servidor deja solo el mensaje de fecha',
    (tester) async {
      final repository = await _pump(tester);
      await _serverFailure(tester);
      expect(repository.drafts, hasLength(1));
      await tester.enterText(_field('Visible hasta: fecha'), '10/11/2026');
      await tester.pumpAndSettle();
      expect(find.text(_serverError), findsOneWidget);
      await _publish(tester);
      expect(find.text(_endError), findsOneWidget);
      expect(find.text(_serverError), findsNothing);
      expect(repository.drafts, hasLength(1));
    },
  );

  testWidgets(
    'a 320 px con texto x2 permite corregir publicación sin desbordes',
    (tester) async {
      await _pump(tester, width: 320, scale: 2);
      await _contentFailure(tester);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        _field('Texto de la novedad'),
        'Atención el viernes.',
      );
      await tester.pumpAndSettle();
      expect(find.text(_contentError), findsNothing);
      await _tap(tester, find.text('Agregar imágenes'));
      for (final name in ['primera.png', 'segunda.png']) {
        await tester.ensureVisible(find.byTooltip('Quitar imagen $name'));
        expect(
          find.byTooltip('Quitar imagen $name').hitTestable(),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
