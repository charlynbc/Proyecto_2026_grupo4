import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/estadisticas/referrals/models/referral_statistics.dart';
import 'package:agenda_medica/features/estadisticas/referrals/providers/referral_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/referrals/repositories/referral_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/tabs/referral_statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ReferralItem _item(
  String name,
  int used,
  int available,
  int expired, {
  String utilization = 'Sin datos',
}) => ReferralItem(
  name: name,
  issued: used + available + expired,
  used: used,
  available: available,
  expired: expired,
  percentage: null,
  utilization: utilization,
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

Finder _inData(int row, String text) => find.descendant(
  of: find.byKey(Key('referral-data-$row')),
  matching: find.text(text),
);

void main() {
  testWidgets('cada fila del gráfico lleva los cinco datos y ya no hay '
      'tarjetas', (tester) async {
    await _pump(
      tester,
      _Repo(
        all: [
          _item('Cardiología', 5, 3, 2, utilization: '71.43 %'),
          _item('Pediatría', 2, 1, 1, utilization: '66.67 %'),
        ],
      ),
    );

    expect(_chart(), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    for (final text in [
      'Emitidos: 10',
      'Utilizados: 5',
      'Disponibles: 3',
      'Vencidos: 2',
      'Utilización: 71.43 %',
    ]) {
      expect(_inData(0, text), findsOneWidget, reason: text);
    }
    for (final text in [
      'Emitidos: 4',
      'Utilizados: 2',
      'Disponibles: 1',
      'Vencidos: 1',
      'Utilización: 66.67 %',
    ]) {
      expect(_inData(1, text), findsOneWidget, reason: text);
    }
    // Cada dato aparece una sola vez: nada queda duplicado.
    expect(find.text('Emitidos: 10'), findsOneWidget);
    expect(find.text('Utilización: 71.43 %'), findsOneWidget);
  });

  testWidgets('con el filtro de origen el gráfico y su línea de datos se '
      'recalculan con lo que llega', (tester) async {
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
    expect(find.text('Dermatología'), findsOneWidget);
    expect(_inData(0, 'Emitidos: 6'), findsOneWidget);
    expect(_inData(0, 'Utilizados: 0'), findsOneWidget);
    expect(_inData(0, 'Vencidos: 6'), findsOneWidget);
    expect(find.text('Emitidos: 10'), findsNothing);
  });

  testWidgets('sin especialidades dice Sin datos y no hay gráfico', (
    tester,
  ) async {
    await _pump(tester, _Repo(all: const []));

    expect(find.byKey(const Key('stats-empty')), findsOneWidget);
    expect(find.text('Sin datos'), findsOneWidget);
    expect(_chart(), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('con todo en cero se muestran las filas sin barra y con su '
      'línea de datos', (tester) async {
    await _pump(
      tester,
      _Repo(all: [_item('Cardiología', 0, 0, 0), _item('Pediatría', 0, 0, 0)]),
    );

    expect(_chart(), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byKey(const Key('referral-track-0')), findsNothing);
    expect(find.byKey(const Key('referral-track-1')), findsNothing);
    expect(find.text('sin pases'), findsNWidgets(2));
    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.text('Pediatría'), findsOneWidget);
    expect(find.text('Emitidos: 0'), findsNWidgets(2));
    expect(find.text('Utilización: Sin datos'), findsNWidgets(2));
  });

  testWidgets('una especialidad sin pases se ve sin barra entre las demás, '
      'con su línea de datos', (tester) async {
    await _pump(
      tester,
      _Repo(
        all: [
          _item('Cardiología', 5, 3, 2, utilization: '71.43 %'),
          _item('Odontología', 0, 0, 0),
        ],
      ),
    );

    expect(find.byKey(const Key('referral-track-0')), findsOneWidget);
    expect(find.byKey(const Key('referral-track-1')), findsNothing);
    expect(find.text('sin pases'), findsOneWidget);
    expect(_inData(1, 'Emitidos: 0'), findsOneWidget);
    expect(_inData(1, 'Utilización: Sin datos'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });
}
