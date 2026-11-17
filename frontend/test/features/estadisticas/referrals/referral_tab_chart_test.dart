import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/estadisticas/referrals/models/referral_statistics.dart';
import 'package:agenda_medica/features/estadisticas/referrals/providers/referral_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/referrals/repositories/referral_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/tabs/referral_statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Devuelve `all` sin filtro y `filtered` cuando se elige una especialidad de
/// origen.
class _Repo implements ReferralStatisticsRepository {
  _Repo({required this.all, this.filtered = const []});

  final List<ReferralItem> all;
  final List<ReferralItem> filtered;
  final selected = <int?>[];

  @override
  Future<ReferralStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
  }) async {
    selected.add(specialtyId);
    return ReferralStatistics(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 9, 30),
      items: specialtyId == null ? all : filtered,
    );
  }
}

Future<void> _pump(WidgetTester tester, _Repo repo) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        referralStatisticsRepositoryProvider.overrideWith((ref) async => repo),
        specialtiesProvider.overrideWith(
          (ref) async => [
            const Specialty(
              id: 3,
              name: 'Medicina general',
              requiresReferral: false,
            ),
          ],
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: ReferralStatisticsTab())),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _chart() => find.byKey(const Key('referral-chart'));

void main() {
  testWidgets('el gráfico va arriba y las tarjetas con los conteos exactos '
      'se conservan debajo', (tester) async {
    await _pump(
      tester,
      _Repo(all: [_item('Cardiología', 5, 3, 2), _item('Pediatría', 2, 1, 1)]),
    );

    expect(_chart(), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
    for (final label in [
      'Emitidos: 10',
      'Utilizados: 5',
      'Disponibles: 3',
      'Vencidos: 2',
      'Emitidos: 4',
      'Utilizados: 2',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // El gráfico está encima de la primera tarjeta.
    expect(
      tester.getBottomLeft(_chart()).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(Card).first).dy),
    );
  });

  testWidgets('con el filtro de origen el gráfico se recalcula con lo que '
      'llega', (tester) async {
    final repo = _Repo(
      all: [_item('Cardiología', 5, 3, 2), _item('Pediatría', 2, 1, 1)],
      filtered: [_item('Dermatología', 0, 0, 6)],
    );
    await _pump(tester, repo);
    expect(find.byKey(const Key('referral-track-1')), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medicina general').last);
    await tester.pumpAndSettle();

    expect(repo.selected, [null, 3]);
    // Una sola especialidad, solo vencidos, que ocupa todo el ancho.
    expect(find.byKey(const Key('referral-track-0')), findsOneWidget);
    expect(find.byKey(const Key('referral-track-1')), findsNothing);
    expect(find.byKey(const Key('referral-seg-0-used')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('referral-seg-0-expired'))).width,
      closeTo(
        tester.getSize(find.byKey(const Key('referral-track-0'))).width,
        0.5,
      ),
    );
    expect(find.text('Cardiología'), findsNothing);
    expect(find.text('Dermatología'), findsWidgets);
  });

  testWidgets('sin especialidades dice Sin datos y no hay gráfico ni '
      'tarjetas', (tester) async {
    await _pump(tester, _Repo(all: const []));

    expect(find.byKey(const Key('stats-empty')), findsOneWidget);
    expect(find.text('Sin datos'), findsOneWidget);
    expect(_chart(), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('con todo en cero no hay gráfico pero sí las tarjetas', (
    tester,
  ) async {
    await _pump(
      tester,
      _Repo(all: [_item('Cardiología', 0, 0, 0), _item('Pediatría', 0, 0, 0)]),
    );

    expect(_chart(), findsNothing);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text('Emitidos: 0'), findsNWidgets(2));
  });

  testWidgets('una especialidad sin pases se ve sin barra entre las demás', (
    tester,
  ) async {
    await _pump(
      tester,
      _Repo(
        all: [_item('Cardiología', 5, 3, 2), _item('Odontología', 0, 0, 0)],
      ),
    );

    expect(find.byKey(const Key('referral-track-0')), findsOneWidget);
    expect(find.byKey(const Key('referral-track-1')), findsNothing);
    expect(find.text('sin pases'), findsOneWidget);
    // Las dos tienen su tarjeta.
    expect(find.byType(Card), findsNWidgets(2));
  });
}
