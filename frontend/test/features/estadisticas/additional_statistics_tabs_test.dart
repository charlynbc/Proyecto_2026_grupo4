import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/estadisticas/referrals/models/referral_statistics.dart';
import 'package:agenda_medica/features/estadisticas/referrals/providers/referral_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/referrals/repositories/referral_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/tabs/referral_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/time_slot_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/models/time_slot_statistics.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/providers/time_slot_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/repositories/time_slot_statistics_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Referrals implements ReferralStatisticsRepository {
  int? selected;
  int calls = 0;
  DateTime? lastFrom, lastTo;
  Completer<ReferralStatistics>? pending;
  bool fails = false;
  @override
  Future<ReferralStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
  }) async {
    calls++;
    selected = specialtyId;
    lastFrom = from;
    lastTo = to;
    if (fails) {
      throw const ApiException(
        'Tu cuenta no tiene permiso para ver las estadísticas.',
      );
    }
    if (pending != null) return pending!.future;
    return ReferralStatistics(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 9, 30),
      items: const [
        ReferralItem(
          name: 'Cardiología',
          issued: 3,
          used: 0,
          available: 3,
          expired: 0,
          percentage: null,
          utilization: 'Sin datos',
        ),
      ],
    );
  }
}

class Slots implements TimeSlotStatisticsRepository {
  TimeSlotView? selected;
  int? specialty;
  DateTime? lastFrom, lastTo;
  int calls = 0;
  Completer<TimeSlotStatistics>? pending;
  @override
  Future<TimeSlotStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
    required TimeSlotView view,
  }) async {
    selected = view;
    specialty = specialtyId;
    lastFrom = from;
    lastTo = to;
    calls++;
    if (pending != null) return pending!.future;
    return TimeSlotStatistics(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 9, 30),
      cells: const [TimeSlotCell(day: 2, hour: 9, count: 2)],
    );
  }
}

void main() {
  testWidgets('pases muestra los cuatro conteos y la utilización del API', (
    tester,
  ) async {
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'desde': '2026-09-01',
              'hasta': '2026-09-30',
              'items': [
                {
                  'especialidadDestino': {'id': 3, 'nombre': 'Cardiología'},
                  'emitidos': 10,
                  'utilizados': 5,
                  'disponibles': 3,
                  'vencidos': 2,
                  'porcentajeUtilizados': 71.43,
                  'utilizacion': '71.43 %',
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralStatisticsRepositoryProvider.overrideWith(
            (ref) async => ApiReferralStatisticsRepository(dio),
          ),
          specialtiesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: ReferralStatisticsTab())),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.ancestor(
      of: find.text('Cardiología'),
      matching: find.byType(Card),
    );
    expect(card, findsOneWidget);
    for (final label in [
      'Emitidos: 10',
      'Utilizados: 5',
      'Disponibles: 3',
      'Vencidos: 2',
      'Utilización: 71.43 %',
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(label)),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'pases muestra período del servidor, utilización y filtra origen',
    (tester) async {
      final repo = Referrals();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            referralStatisticsRepositoryProvider.overrideWith(
              (ref) async => repo,
            ),
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
          child: const MaterialApp(
            home: Scaffold(body: ReferralStatisticsTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Datos del 01/09/2026 al 30/09/2026'), findsOneWidget);
      expect(find.text('Utilización: Sin datos'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('stats-period-label'))).dy,
        lessThan(tester.getTopLeft(find.text('Cardiología')).dy),
      );
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medicina general').last);
      await tester.pumpAndSettle();
      expect(repo.selected, 3);
      expect(repo.calls, 2);
      await tester.enterText(find.byKey(const Key('stats-from')), '05/10/2026');
      await tester.enterText(find.byKey(const Key('stats-to')), '20/10/2026');
      await tester.tap(find.byKey(const Key('stats-consult')));
      await tester.pumpAndSettle();
      expect(repo.lastFrom, DateTime.utc(2026, 10, 5));
      expect(repo.lastTo, DateTime.utc(2026, 10, 20));
      expect(find.text('Datos del 01/09/2026 al 30/09/2026'), findsOneWidget);
      repo.pending = Completer<ReferralStatistics>();
      await tester.tap(find.byKey(const Key('stats-consult')));
      await tester.pump();
      expect(find.byKey(const Key('stats-loading')), findsOneWidget);
      expect(find.byKey(const Key('stats-period-label')), findsNothing);
      repo.pending!.completeError(
        const ApiException(
          'Tu cuenta no tiene permiso para ver las estadísticas.',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Tu cuenta no tiene permiso para ver las estadísticas.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('stats-period-label')), findsNothing);
    },
  );

  testWidgets('franjas muestra mapa y solicita la vista de llegadas a 320 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = Slots();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timeSlotStatisticsRepositoryProvider.overrideWith(
            (ref) async => repo,
          ),
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
        child: const MaterialApp(home: Scaffold(body: TimeSlotStatisticsTab())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Datos del 01/09/2026 al 30/09/2026'), findsOneWidget);
    expect(
      find.text('Cantidad por día y hora (hora de Uruguay)'),
      findsOneWidget,
    );
    expect(
      tester.getCenter(find.text('2')).dx,
      closeTo(tester.getCenter(find.text('Mar')).dx, 0.1),
    );
    await tester.tap(find.text('Llegadas'));
    await tester.pumpAndSettle();
    expect(repo.selected, TimeSlotView.arrivals);
    await tester.tap(find.text('Todas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medicina general').last);
    await tester.pumpAndSettle();
    expect(repo.specialty, 3);
    await tester.enterText(find.byKey(const Key('stats-from')), '05/10/2026');
    await tester.enterText(find.byKey(const Key('stats-to')), '20/10/2026');
    await tester.tap(find.byKey(const Key('stats-consult')));
    await tester.pumpAndSettle();
    expect(repo.lastFrom, DateTime.utc(2026, 10, 5));
    expect(repo.lastTo, DateTime.utc(2026, 10, 20));
    expect(repo.calls, 4);
    expect(find.text('Datos del 01/09/2026 al 30/09/2026'), findsOneWidget);
    repo.pending = Completer<TimeSlotStatistics>();
    await tester.tap(find.byKey(const Key('stats-consult')));
    await tester.pump();
    expect(find.byKey(const Key('stats-loading')), findsOneWidget);
    expect(find.byKey(const Key('stats-period-label')), findsNothing);
    repo.pending!.completeError(
      const ApiException(
        'Tu cuenta no tiene permiso para ver las estadísticas.',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Tu cuenta no tiene permiso para ver las estadísticas.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('stats-period-label')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
