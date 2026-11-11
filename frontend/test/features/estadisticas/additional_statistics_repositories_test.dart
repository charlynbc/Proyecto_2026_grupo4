import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/estadisticas/referrals/repositories/referral_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/repositories/time_slot_statistics_repository.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.body, {this.status = 200});
  final Object body;
  final int status;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final dates = {'desde': '2026-10-01', 'hasta': '2026-10-31'};
  test('pases envía origen solo cuando está seleccionado', () async {
    final adapter = Adapter({...dates, 'items': []});
    final repo = ApiReferralStatisticsRepository(
      Dio()..httpClientAdapter = adapter,
    );
    await repo.statistics();
    expect(adapter.last!.path, '/api/estadisticas/pases');
    expect(adapter.last!.queryParameters, isEmpty);
    await repo.statistics(
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 31),
      specialtyId: 3,
    );
    expect(adapter.last!.queryParameters, {
      'desde': '2026-10-01',
      'hasta': '2026-10-31',
      'especialidadOrigenId': 3,
    });
  });
  test('franjas envía la vista y el filtro opcional', () async {
    final adapter = Adapter({...dates, 'celdas': []});
    final repo = ApiTimeSlotStatisticsRepository(
      Dio()..httpClientAdapter = adapter,
    );
    await repo.statistics(view: TimeSlotView.consultations);
    expect(adapter.last!.path, '/api/estadisticas/franjas');
    expect(adapter.last!.queryParameters, {'vista': 'CONSULTAS'});
    await repo.statistics(view: TimeSlotView.arrivals, specialtyId: 3);
    expect(adapter.last!.queryParameters, {
      'vista': 'LLEGADAS',
      'especialidadId': 3,
    });
  });
  test('ambas estadísticas muestran mensaje propio ante 403', () async {
    final adapter = Adapter({'message': 'texto privado'}, status: 403);
    final dio = Dio()..httpClientAdapter = adapter;
    const message = 'Tu cuenta no tiene permiso para ver las estadísticas.';
    await expectLater(
      ApiReferralStatisticsRepository(dio).statistics(),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', message)),
    );
    await expectLater(
      ApiTimeSlotStatisticsRepository(dio)
          .statistics(view: TimeSlotView.arrivals),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', message)),
    );
  });
  test(
    'el fake de franjas conserva 168 celdas y distingue las vistas',
    () async {
      final fake = FakeTimeSlotStatisticsRepository(
        clock: () => DateTime.utc(2026, 10, 15, 12),
      );
      final consultations = await fake.statistics(
        view: TimeSlotView.consultations,
      );
      final arrivals = await fake.statistics(view: TimeSlotView.arrivals);
      expect(consultations.cells, hasLength(168));
      expect(consultations.cells.first.day, 1);
      expect(consultations.cells.first.hour, 0);
      expect(consultations.cells[8].count, 1);
      expect(arrivals.cells[8].count, 2);
      final filtered = await fake.statistics(
        view: TimeSlotView.consultations,
        specialtyId: 2,
      );
      expect(filtered.cells[8].count, 0);
    },
  );
  test('el fake de pases conserva destinos sin pases resueltos', () async {
    final fake = FakeReferralStatisticsRepository(
      clock: () => DateTime.utc(2026, 10, 15, 12),
    );
    final all = await fake.statistics();
    final filtered = await fake.statistics(specialtyId: 2);
    expect(all.items.first.issued, 10);
    expect(all.items.last.utilization, 'Sin datos');
    expect(all.items.last.percentage, isNull);
    expect(filtered.items, hasLength(2));
    expect(filtered.items.first.issued, 0);
  });
}
