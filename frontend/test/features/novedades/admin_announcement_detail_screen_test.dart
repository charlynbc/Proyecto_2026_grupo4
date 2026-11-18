import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/widgets/announcement_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import 'admin_test_support.dart';

const _image = AnnouncementImage(
  id: 101,
  order: 0,
  url: 'https://example.invalid/imagen-101',
);

/// 30 vigente en la posición 2 (sin imágenes), 20 programada del 20/11 al
/// 21/11 y 10 vencida el 01/11, con resumen e imagen.
AdminTestRepo _repo() => AdminTestRepo(
  seed: [
    adminTestEntry(
      30,
      'Jornada de vacunación',
      published: DateTime.utc(2026, 11, 12, 12),
      until: DateTime.utc(2026, 12, 1, 3),
      position: 2,
    ),
    adminTestEntry(
      20,
      'Horarios de verano',
      published: DateTime.utc(2026, 11, 10, 12),
      from: DateTime.utc(2026, 11, 20, 3),
      until: DateTime.utc(2026, 11, 21, 2, 59),
    ),
    adminTestEntry(
      10,
      'Campaña anterior',
      published: DateTime.utc(2026, 10, 1, 12),
      until: DateTime.utc(2026, 11, 1, 3),
      summary: 'Resumen de la campaña',
      images: const [_image],
    ),
  ],
);

Future<void> _open(WidgetTester tester, AdminTestRepo repo, int id) =>
    pumpAdminScreen(
      tester,
      repo,
      location: '/admin/cartelera/$id?desde=cartelera',
    );

void main() {
  setUpAll(loadRoboto);

  testWidgets('el detalle de una vencida muestra título, resumen, texto, '
      'estado y fechas', (tester) async {
    final repo = _repo();
    await _open(tester, repo, 10);

    expect(find.text('Campaña anterior'), findsOneWidget);
    expect(find.text('Resumen de la campaña'), findsOneWidget);
    expect(find.text('Texto 10'), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);
    expect(find.text('Publicado el 01/10/2026'), findsOneWidget);
    expect(find.text('Se ve desde: la publicación'), findsOneWidget);
    expect(find.text('Se deja de ver: 01/11/2026 00:00'), findsOneWidget);
    expect(find.byType(AnnouncementGallery), findsOneWidget);
  });

  testWidgets('el detalle de una programada muestra inicio y fin', (
    tester,
  ) async {
    await _open(tester, _repo(), 20);

    expect(find.text('Horarios de verano'), findsOneWidget);
    expect(find.text('Texto 20'), findsOneWidget);
    expect(find.text('Programado'), findsOneWidget);
    expect(find.text('Se ve desde: 20/11/2026 00:00'), findsOneWidget);
    expect(find.text('Se deja de ver: 20/11/2026 23:59'), findsOneWidget);
    expect(find.byType(AnnouncementGallery), findsNothing);
  });

  testWidgets('el detalle de una vigente muestra su posición en el carrusel', (
    tester,
  ) async {
    await _open(tester, _repo(), 30);

    expect(find.text('Jornada de vacunación'), findsOneWidget);
    expect(find.text('Vigente'), findsOneWidget);
    expect(find.text('Se deja de ver: 01/12/2026 00:00'), findsOneWidget);
    expect(find.text('En el carrusel: posición 2'), findsOneWidget);
  });

  testWidgets('no llama al endpoint público: pide solo el detalle de '
      'administración', (tester) async {
    final repo = _repo();
    await _open(tester, repo, 10);

    expect(repo.adminDetailIds, [10]);
    expect(repo.detailIds, isEmpty);
  });

  testWidgets('si la novedad no existe muestra el mensaje y la lista se '
      'actualiza', (tester) async {
    final repo = _repo();
    await _open(tester, repo, 99);

    expect(find.text('No encontramos esta novedad.'), findsOneWidget);
    expect(repo.adminDetailIds, [99]);
    expect(repo.detailIds, isEmpty);
  });

  testWidgets('con un error de red muestra el mensaje y Reintentar lo '
      'resuelve', (tester) async {
    final repo = _repo()..adminDetailError = const ApiException('Sin red.');
    await _open(tester, repo, 10);

    expect(find.text('No pudimos cargar la novedad.'), findsOneWidget);
    expect(find.text('Sin red.'), findsOneWidget);
    expect(find.text('Campaña anterior'), findsNothing);

    repo.adminDetailError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Campaña anterior'), findsOneWidget);
    expect(find.text('No pudimos cargar la novedad.'), findsNothing);
    expect(repo.adminDetailIds, [10, 10]);
  });

  testWidgets('mientras carga muestra Cargando novedad', (tester) async {
    final repo = _repo()..adminDetailPending = Completer<void>();
    await _open(tester, repo, 10);

    expect(find.text('Cargando novedad…'), findsOneWidget);

    repo.adminDetailPending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Campaña anterior'), findsOneWidget);
  });

  testWidgets('Volver a novedades regresa a la Cartelera', (tester) async {
    final container = await pumpAdminScreen(
      tester,
      _repo(),
      location: '/admin/cartelera/10?desde=cartelera',
    );

    await tester.tap(find.text('Volver a novedades').last);
    await tester.pumpAndSettle();

    expect(locationOf(container), '/admin/cartelera');
    expect(find.byKey(const ValueKey('admin-announcement-10')), findsOneWidget);
  });
}
