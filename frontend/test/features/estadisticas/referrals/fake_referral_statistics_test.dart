import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/estadisticas/referrals/models/referral_statistics.dart';
import 'package:agenda_medica/features/estadisticas/referrals/repositories/referral_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/tabs/referral_statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// El catálogo del Fake de administración: 1 Medicina General (pase libre),
/// 2 Cardiología y 3 Dermatología (exigen pase).
FakeReferralStatisticsRepository _fake() => FakeReferralStatisticsRepository(
  clock: () => DateTime.utc(2026, 10, 15, 12),
);

List<String> _names(ReferralStatistics data) => [
  for (final item in data.items) item.name,
];

void main() {
  group('el fake devuelve el contrato completo', () {
    test('con Todas: una fila por especialidad del catálogo', () async {
      final data = await _fake().statistics();

      // Orden del servidor: emitidos descendente y después nombre.
      expect(_names(data), ['Cardiología', 'Dermatología', 'Medicina General']);
      expect(
        [for (final i in data.items) i.requiresReferral],
        [true, true, false],
      );
      final cardiology = data.items[0];
      expect(cardiology.issued, 10);
      expect(cardiology.used, 5);
      expect(cardiology.available, 3);
      expect(cardiology.expired, 2);
      expect(cardiology.percentage, 71.43);
      expect(cardiology.utilization, '71.43 %');
      for (final item in data.items.skip(1)) {
        expect(item.issued, 0, reason: item.name);
        expect(item.utilization, 'Sin datos', reason: item.name);
        expect(item.percentage, isNull, reason: item.name);
      }
    });

    test('con cada origen: las mismas tres filas', () async {
      for (final origin in [1, 2, 3]) {
        final data = await _fake().statistics(specialtyId: origin);
        expect(_names(data), [
          'Cardiología',
          'Dermatología',
          'Medicina General',
        ], reason: 'origen $origin');
      }
    });

    test('los pases son de Medicina General: solo ese origen y Todas los '
        'ven', () async {
      final byOrigin = <int?, int>{};
      for (final origin in <int?>[null, 1, 2, 3]) {
        final data = await _fake().statistics(specialtyId: origin);
        byOrigin[origin] = data.items.fold<int>(0, (sum, i) => sum + i.issued);
      }
      expect(byOrigin, {null: 10, 1: 10, 2: 0, 3: 0});
      // La suma de los orígenes da el total de Todas.
      expect(byOrigin[1]! + byOrigin[2]! + byOrigin[3]!, byOrigin[null]);
    });

    test(
      'una especialidad nueva del catálogo aparece con cero pases',
      () async {
        final fake = FakeReferralStatisticsRepository(
          clock: () => DateTime.utc(2026, 10, 15, 12),
          catalog: () => const [
            Specialty(id: 1, name: 'Medicina General', requiresReferral: false),
            Specialty(id: 2, name: 'Cardiología', requiresReferral: true),
            Specialty(id: 9, name: 'Neurología', requiresReferral: true),
          ],
        );
        final data = await fake.statistics();

        expect(_names(data), ['Cardiología', 'Medicina General', 'Neurología']);
        expect(data.items.last.requiresReferral, isTrue);
        expect(data.items.last.issued, 0);
      },
    );
  });

  group('la pantalla con fakes muestra solo Cardiología y Dermatología', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            useFakesProvider.overrideWithValue(true),
            fakeAdminDatabaseProvider.overrideWith(
              (ref) => FakeAdminDatabase(),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ReferralStatisticsTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder rowName(int row, String name) => find.descendant(
      of: find.byKey(Key('referral-row-$row')),
      matching: find.text(name),
    );

    void expectOnlyCardiologyAndDermatology(WidgetTester tester) {
      expect(find.byKey(const Key('referral-row-0')), findsOneWidget);
      expect(find.byKey(const Key('referral-row-1')), findsOneWidget);
      expect(find.byKey(const Key('referral-row-2')), findsNothing);
      expect(rowName(0, 'Cardiología'), findsOneWidget);
      expect(rowName(1, 'Dermatología'), findsOneWidget);
    }

    testWidgets('con Todas', (tester) async {
      await pump(tester);

      expectOnlyCardiologyAndDermatology(tester);
      // Cardiología con sus 10 pases y Dermatología sin pases.
      expect(find.text('Emitidos: 10'), findsOneWidget);
      expect(find.byKey(const Key('referral-none-1')), findsOneWidget);
    });

    for (final (origin, label) in [
      ('Medicina General', 'Medicina General'),
      ('Cardiología', 'Cardiología'),
      ('Dermatología', 'Dermatología'),
    ]) {
      testWidgets('con origen $label', (tester) async {
        await pump(tester);
        await tester.tap(find.text('Todas'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(origin).last);
        await tester.pumpAndSettle();

        expectOnlyCardiologyAndDermatology(tester);
        // Medicina General solo se ve, si acaso, como el origen elegido en el
        // selector: ninguna fila del gráfico la muestra.
        expect(
          find.descendant(
            of: find.byKey(const Key('referral-chart')),
            matching: find.text('Medicina General'),
          ),
          findsNothing,
        );
      });
    }
  });
}
