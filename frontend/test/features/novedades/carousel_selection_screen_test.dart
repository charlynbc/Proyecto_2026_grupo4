import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:agenda_medica/features/novedades/screens/carousel_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import 'admin_test_support.dart';

Finder _slot(int position) => find.byKey(ValueKey('carousel-slot-$position'));

Finder _warning(int position) =>
    find.byKey(ValueKey('carousel-warning-$position'));

const _notActive = 'No está vigente: no se muestra a los socios.';

DateTime get _published => DateTime.utc(2026, 11, 1, 12);

/// Seis novedades vigentes, para poder llenar las cinco posiciones.
List<FakeAnnouncementEntry> _manySeed() => [
  for (var id = 1; id <= 6; id++)
    adminTestEntry(id, 'Novedad $id', published: _published),
];

Future<void> _open(
  WidgetTester tester,
  AdminTestRepo repo, {
  double width = 1280,
  double scale = 1,
}) async {
  await pumpAdminScreen(
    tester,
    repo,
    width: width,
    scale: scale,
    location: '/admin/cartelera/carrusel',
  );
}

Future<void> _choose(WidgetTester tester, int position, String label) async {
  await tester.ensureVisible(_slot(position));
  await tester.tap(_slot(position));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Guardar carrusel');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Iterable<(int, int)> _pairs(List<CarouselSlot> slots) =>
    slots.map((s) => (s.position, s.announcementId));

void main() {
  setUpAll(loadRoboto);

  testWidgets('muestra las cinco posiciones con la selección guardada', (
    tester,
  ) async {
    await _open(tester, AdminTestRepo());

    for (var position = 1; position <= 5; position++) {
      expect(_slot(position), findsOneWidget, reason: 'posición $position');
    }
    expect(
      find.descendant(
        of: _slot(2),
        matching: find.text('Jornada de vacunación (Vigente)'),
      ),
      findsOneWidget,
    );
    for (final position in [1, 3, 4, 5]) {
      expect(
        find.descendant(
          of: _slot(position),
          matching: find.text('Sin novedad'),
        ),
        findsOneWidget,
        reason: 'posición $position',
      );
    }
  });

  testWidgets('el título de la pantalla es Carrusel del Inicio', (
    tester,
  ) async {
    await _open(tester, AdminTestRepo());

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Carrusel del Inicio'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('avisa que lo no vigente no se muestra a los socios', (
    tester,
  ) async {
    await _open(tester, AdminTestRepo());

    expect(
      find.textContaining('no se muestra a los socios aunque esté elegida'),
      findsOneWidget,
    );
  });

  testWidgets('elegir una novedad no vigente lo avisa en esa posición', (
    tester,
  ) async {
    await _open(tester, AdminTestRepo());
    expect(_warning(1), findsNothing);

    await _choose(tester, 1, 'Horarios de verano (Programado)');
    await _choose(tester, 3, 'Campaña anterior (Vencido)');

    expect(
      find.descendant(of: _warning(1), matching: find.text(_notActive)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _warning(3), matching: find.text(_notActive)),
      findsOneWidget,
    );
    // La posición 2 tiene una vigente: sin aviso.
    expect(_warning(2), findsNothing);
  });

  group('guardar', () {
    testWidgets('con huecos (posiciones 1 y 3) manda exactamente esas dos', (
      tester,
    ) async {
      final repo = AdminTestRepo();
      await _open(tester, repo);
      await _choose(tester, 2, 'Sin novedad');
      await _choose(tester, 1, 'Jornada de vacunación (Vigente)');
      await _choose(tester, 3, 'Horarios de verano (Programado)');

      await _save(tester);

      expect(repo.saves, hasLength(1));
      expect(_pairs(repo.saves.single), [(1, 30), (3, 20)]);
    });

    testWidgets('manda la selección completa y no solo la posición tocada', (
      tester,
    ) async {
      final repo = AdminTestRepo(
        seed: [
          adminTestEntry(1, 'Novedad 1', published: _published, position: 1),
          adminTestEntry(2, 'Novedad 2', published: _published, position: 2),
          adminTestEntry(3, 'Novedad 3', published: _published),
        ],
      );
      await _open(tester, repo);
      await _choose(tester, 3, 'Novedad 3 (Vigente)');

      await _save(tester);

      expect(_pairs(repo.saves.single), [(1, 1), (2, 2), (3, 3)]);
    });

    testWidgets('guardar reemplaza lo anterior y cambia el carrusel del '
        'Inicio', (tester) async {
      final repo = AdminTestRepo(
        seed: [
          adminTestEntry(1, 'Novedad 1', published: _published, position: 1),
          adminTestEntry(2, 'Novedad 2', published: _published),
          adminTestEntry(3, 'Novedad 3', published: _published),
        ],
      );
      await _open(tester, repo);
      await _choose(tester, 1, 'Sin novedad');
      await _choose(tester, 5, 'Novedad 3 (Vigente)');
      await _choose(tester, 2, 'Novedad 2 (Vigente)');

      await _save(tester);

      expect((await repo.carousel()).map((a) => a.id), [2, 3]);
      expect(_pairs(await repo.adminCarousel()), [(2, 2), (5, 3)]);
    });

    testWidgets('dejar todo vacío guarda una selección vacía', (tester) async {
      final repo = AdminTestRepo();
      await _open(tester, repo);
      await _choose(tester, 2, 'Sin novedad');

      await _save(tester);

      expect(repo.saves.single, isEmpty);
      expect(await repo.carousel(), isEmpty);
    });

    testWidgets('permite llenar las cinco posiciones', (tester) async {
      final repo = AdminTestRepo(seed: _manySeed());
      await _open(tester, repo);
      for (var position = 1; position <= 5; position++) {
        await _choose(tester, position, 'Novedad $position (Vigente)');
      }

      await _save(tester);

      expect(_pairs(repo.saves.single), [
        (1, 1),
        (2, 2),
        (3, 3),
        (4, 4),
        (5, 5),
      ]);
    });

    testWidgets('la misma novedad en dos posiciones no se guarda', (
      tester,
    ) async {
      final repo = AdminTestRepo();
      await _open(tester, repo);
      await _choose(tester, 1, 'Jornada de vacunación (Vigente)');

      await _save(tester);

      expect(repo.saves, isEmpty);
      expect(find.text('Elegí cada novedad una sola vez.'), findsOneWidget);
    });

    testWidgets('al guardar vuelve a la Cartelera con el aviso', (
      tester,
    ) async {
      final repo = AdminTestRepo();
      await _open(tester, repo);
      await _choose(tester, 3, 'Horarios de verano (Programado)');

      await _save(tester);

      expect(find.byType(CarouselSelectionScreen), findsNothing);
      expect(find.text('Carrusel guardado'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-announcement-30')),
        findsOneWidget,
      );
    });

    testWidgets('un 400 del servidor muestra su mensaje y no cierra', (
      tester,
    ) async {
      final repo = AdminTestRepo()
        ..saveError = const ApiException('Selección inválida de prueba');
      await _open(tester, repo);
      await _choose(tester, 3, 'Horarios de verano (Programado)');

      await _save(tester);

      expect(find.text('Selección inválida de prueba'), findsOneWidget);
      expect(find.byType(CarouselSelectionScreen), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardar carrusel'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('un 404 (otra persona eliminó una elegida) muestra el '
        'mensaje', (tester) async {
      final repo = AdminTestRepo();
      await _open(tester, repo);
      await _choose(tester, 3, 'Horarios de verano (Programado)');
      await repo.deleteBehindTheScenes(20);

      await _save(tester);

      expect(find.text('Anuncio no encontrado'), findsOneWidget);
      expect(find.byType(CarouselSelectionScreen), findsOneWidget);
    });

    testWidgets('mientras guarda deshabilita todo y no duplica el envío', (
      tester,
    ) async {
      final repo = AdminTestRepo()..savePending = Completer<void>();
      await _open(tester, repo);
      await _choose(tester, 3, 'Horarios de verano (Programado)');
      final save = find.widgetWithText(FilledButton, 'Guardar carrusel');
      await tester.ensureVisible(save);

      await tester.tap(save);
      await tester.pump();

      final saving = find.widgetWithText(FilledButton, 'Guardando…');
      expect(saving, findsOneWidget);
      expect(tester.widget<FilledButton>(saving).onPressed, isNull);
      await tester.tap(saving, warnIfMissed: false);
      await tester.pump();
      expect(repo.saves, hasLength(1));
      for (var position = 1; position <= 5; position++) {
        expect(
          tester
              .widget<DropdownButtonFormField<int?>>(_slot(position))
              .onChanged,
          isNull,
          reason: 'posición $position',
        );
      }

      repo.savePending!.complete();
      await tester.pumpAndSettle();
      expect(repo.saves, hasLength(1));
      expect(find.text('Carrusel guardado'), findsOneWidget);
    });
  });

  group('estados de carga', () {
    testWidgets('mientras carga muestra el aviso', (tester) async {
      final repo = AdminTestRepo()..carouselReadPending = Completer<void>();
      await _open(tester, repo);

      expect(find.text('Cargando el carrusel…'), findsOneWidget);

      repo.carouselReadPending!.complete();
      await tester.pumpAndSettle();
      expect(_slot(1), findsOneWidget);
    });

    testWidgets('un error al leer la selección permite reintentar', (
      tester,
    ) async {
      final repo = AdminTestRepo()
        ..carouselReadError = const ApiException('Servicio de prueba caído');
      await _open(tester, repo);

      expect(find.text('No pudimos cargar el carrusel.'), findsOneWidget);
      expect(find.text('Servicio de prueba caído'), findsOneWidget);

      repo.carouselReadError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(_slot(1), findsOneWidget);
    });

    testWidgets('un error al leer las novedades permite reintentar', (
      tester,
    ) async {
      final repo = AdminTestRepo()
        ..listError = const ApiException('Lista de prueba caída');
      await _open(tester, repo);

      expect(find.text('No pudimos cargar el carrusel.'), findsOneWidget);
      expect(find.text('Lista de prueba caída'), findsOneWidget);

      repo.listError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(_slot(1), findsOneWidget);
    });

    testWidgets('sin novedades no hay nada para elegir', (tester) async {
      await _open(tester, AdminTestRepo(seed: const []));

      expect(
        find.text('Todavía no hay novedades para elegir.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Guardar carrusel'),
        findsNothing,
      );
    });
  });

  group('navegación', () {
    testWidgets('Elegir carrusel abre la pantalla desde la Cartelera', (
      tester,
    ) async {
      await pumpAdminScreen(tester, AdminTestRepo());

      await tester.tap(find.text('Elegir carrusel'));
      await tester.pumpAndSettle();

      expect(find.byType(CarouselSelectionScreen), findsOneWidget);
    });

    testWidgets('Cancelar vuelve sin guardar', (tester) async {
      final repo = AdminTestRepo();
      await pumpAdminScreen(tester, repo);
      await tester.tap(find.text('Elegir carrusel'));
      await tester.pumpAndSettle();
      await _choose(tester, 3, 'Horarios de verano (Programado)');

      final cancel = find.widgetWithText(OutlinedButton, 'Cancelar');
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(find.byType(CarouselSelectionScreen), findsNothing);
      expect(repo.saves, isEmpty);
    });
  });

  group('a 320 px con texto al doble', () {
    testWidgets('las cinco posiciones y los avisos entran sin desbordar', (
      tester,
    ) async {
      final repo = AdminTestRepo(
        seed: [
          adminTestEntry(
            1,
            'Una novedad con un título bastante largo para probar el ajuste',
            published: _published,
            until: DateTime.utc(2026, 11, 1, 13),
            position: 1,
          ),
          adminTestEntry(2, 'Novedad 2', published: _published, position: 2),
        ],
      );
      await _open(tester, repo, width: 320, scale: 2);

      expect(tester.takeException(), isNull);
      for (var position = 1; position <= 5; position++) {
        await tester.ensureVisible(_slot(position));
        final rect = tester.getRect(_slot(position));
        expect(
          rect.left,
          greaterThanOrEqualTo(0),
          reason: 'posición $position',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(320),
          reason: 'posición $position',
        );
      }
      expect(find.text(_notActive), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Guardar carrusel');
      await tester.ensureVisible(save);
      expect(tester.getRect(save).right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('con el menú abierto y un título largo tampoco desborda', (
      tester,
    ) async {
      final repo = AdminTestRepo(
        seed: [
          adminTestEntry(
            1,
            'Una novedad con un título bastante largo para probar el ajuste',
            published: _published,
          ),
        ],
      );
      await _open(tester, repo, width: 320, scale: 2);

      await tester.ensureVisible(_slot(1));
      await tester.tap(_slot(1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
