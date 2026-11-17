import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/estadisticas/referrals/models/referral_statistics.dart';
import 'package:agenda_medica/features/estadisticas/referrals/providers/referral_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/referrals/repositories/referral_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/tabs/referral_statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';

ReferralItem _item(String name, int used, int available, int expired) =>
    ReferralItem(
      name: name,
      issued: used + available + expired,
      used: used,
      available: available,
      expired: expired,
      percentage: null,
      utilization: 'Sin datos',
    );

/// Sin filtro devuelve `all`; con origen, `filtered`.
class _Repo implements ReferralStatisticsRepository {
  _Repo({this.all = const [], this.filtered = const []});

  List<ReferralItem> all;
  List<ReferralItem> filtered;
  Object? error;
  Completer<ReferralStatistics>? pending;

  @override
  Future<ReferralStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
  }) async {
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return ReferralStatistics(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 9, 30),
      items: specialtyId == null ? all : filtered,
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Repo repo, {
  double width = 1200,
  double height = 900,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        referralStatisticsRepositoryProvider.overrideWith((ref) async => repo),
        specialtiesProvider.overrideWith(
          (ref) async => [
            const Specialty(id: 2, name: 'Cardiología', requiresReferral: true),
          ],
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: ReferralStatisticsTab()),
      ),
    ),
  );
  // Con una carga pendiente no se puede esperar a que termine.
  if (repo.pending == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Finder get _origin => find.byType(DropdownButtonFormField<int>);

/// El formulario empieza 16 px debajo del borde superior: es el margen de la
/// pestaña, sin hueco arriba.
const _top = 16.0;

List<ReferralItem> _manyRows() => [
  for (var i = 0; i < 12; i++) _item('Especialidad $i', 5, 3, 2),
];

void main() {
  setUpAll(loadRoboto);

  group('el contenido queda alineado arriba', () {
    testWidgets('sin pases ni especialidades: el formulario está pegado al '
        'margen superior', (tester) async {
      await _pump(tester, _Repo());

      expect(find.text('Sin datos'), findsOneWidget);
      expect(tester.getTopLeft(_origin).dy, _top);
    });

    testWidgets('con un resultado corto: el mismo lugar', (tester) async {
      await _pump(tester, _Repo(all: [_item('Cardiología', 0, 0, 0)]));

      expect(find.text('sin pases'), findsOneWidget);
      expect(tester.getTopLeft(_origin).dy, _top);
    });

    testWidgets('con un resultado largo: el mismo lugar y se desplaza', (
      tester,
    ) async {
      await _pump(tester, _Repo(all: _manyRows()));

      expect(tester.getTopLeft(_origin).dy, _top);
      // 12 filas no entran en 900 px: hay desplazamiento y no se centra.
      expect(find.byType(Scrollable), findsWidgets);
      expect(find.text('Especialidad 11'), findsOneWidget);
    });

    testWidgets('cargando o con error: el mismo lugar', (tester) async {
      final loading = _Repo()..pending = Completer<ReferralStatistics>();
      await _pump(tester, loading);
      expect(find.byKey(const Key('stats-loading')), findsOneWidget);
      expect(tester.getTopLeft(_origin).dy, _top);

      await tester.pumpWidget(const SizedBox());
      final failing = _Repo()..error = const ApiException('Sin red.');
      await _pump(tester, failing);
      expect(find.byKey(const Key('stats-error')), findsOneWidget);
      expect(tester.getTopLeft(_origin).dy, _top);
    });
  });

  group('el formulario no se mueve cuando cambian los resultados', () {
    testWidgets('al pasar de un resultado largo a uno corto con otro origen', (
      tester,
    ) async {
      final repo = _Repo(
        all: _manyRows(),
        filtered: [_item('Cardiología', 0, 0, 0)],
      );
      await _pump(tester, repo);
      final before = tester.getTopLeft(_origin);

      await tester.tap(_origin);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cardiología').last);
      await tester.pumpAndSettle();

      expect(find.text('Especialidad 0'), findsNothing);
      expect(find.text('sin pases'), findsOneWidget);
      expect(tester.getTopLeft(_origin), before);
      expect(tester.getTopLeft(_origin).dy, _top);
    });

    testWidgets('al pasar de vacío a con datos con Consultar', (tester) async {
      final repo = _Repo();
      await _pump(tester, repo);
      final empty = tester.getTopLeft(_origin);

      repo.all = [_item('Cardiología', 5, 3, 2)];
      await tester.tap(find.byKey(const Key('stats-consult')));
      await tester.pumpAndSettle();

      expect(find.text('Emitidos: 10'), findsOneWidget);
      expect(tester.getTopLeft(_origin), empty);
    });
  });

  group('el ancho máximo y el centrado horizontal se mantienen', () {
    testWidgets('a 1200 px el contenido mide 720 y está centrado', (
      tester,
    ) async {
      await _pump(tester, _Repo(all: [_item('Cardiología', 5, 3, 2)]));

      final rect = tester.getRect(_origin);
      expect(rect.left, 240);
      expect(rect.width, 720);
      expect(rect.right, 960);
    });

    testWidgets('a 700 px usa el ancho disponible menos el margen', (
      tester,
    ) async {
      await _pump(tester, _Repo(), width: 700);

      final rect = tester.getRect(_origin);
      expect(rect.left, 16);
      expect(rect.width, 668);
    });

    testWidgets('a 400 px usa el ancho disponible menos el margen', (
      tester,
    ) async {
      await _pump(tester, _Repo(), width: 400);

      final rect = tester.getRect(_origin);
      expect(rect.left, 16);
      expect(rect.width, 368);
    });
  });

  group('a 320 px con el texto al doble', () {
    testWidgets('el formulario sigue arriba y no hay desbordes', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repo(all: [_item('Cardiología', 5, 3, 2)]),
        width: 320,
        height: 640,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(_origin).dy, _top);
      expect(tester.getTopLeft(_origin).dx, 16);
      expect(tester.getRect(_origin).right, lessThanOrEqualTo(320));
    });

    testWidgets('vacío y con texto al doble: el mismo lugar', (tester) async {
      await _pump(tester, _Repo(), width: 320, height: 640, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(_origin).dy, _top);
    });
  });
}
