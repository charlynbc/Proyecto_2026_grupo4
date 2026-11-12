import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:agenda_medica/features/estadisticas/absences/repositories/absence_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/absences/repositories/api_absence_statistics_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// La respuesta de la fila 69, escrita a mano.
Map<String, dynamic> _body() => {
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'agruparPor': 'ESPECIALIDAD',
  'items': <Map<String, dynamic>>[
    {
      'id': 3,
      'nombre': 'Cardiología',
      'apellido': null,
      'atendidas': 20,
      'noAsistio': 2,
      'noSePresento': 1,
      'noAtendidas': 2,
      'total': 25,
      'porcentajeInasistencia': 12.0,
      'inasistencia': '12 %',
    },
  ],
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object? body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
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

(ApiAbsenceStatisticsRepository, _Adapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiAbsenceStatisticsRepository(dio), adapter);
}

void main() {
  test('pide la ruta de inasistencias y lee la respuesta', () async {
    final (repository, adapter) = _repository(200, _body());

    final result = await repository.statistics(
      grouping: AbsenceGrouping.specialty,
    );

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, ApiRoutes.statsAbsences);
    expect(adapter.last!.queryParameters, {'agruparPor': 'ESPECIALIDAD'});
    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.groupedBy, 'ESPECIALIDAD');
    expect(result.items.single.name, 'Cardiología');
    expect(result.items.single.percentage, 12.0);
    expect(result.items.single.percentageText, '12 %');
  });

  test('manda desde, hasta y agruparPor en mayúsculas', () async {
    final (repository, adapter) = _repository(200, _body());

    await repository.statistics(
      from: DateTime.utc(2026, 10, 5),
      to: DateTime.utc(2026, 10, 20),
      grouping: AbsenceGrouping.specialty,
    );

    expect(adapter.last!.queryParameters, {
      'desde': '2026-10-05',
      'hasta': '2026-10-20',
      'agruparPor': 'ESPECIALIDAD',
    });
  });

  test('agrupar por médico manda MEDICO', () async {
    final (repository, adapter) = _repository(200, _body());

    await repository.statistics(
      from: DateTime.utc(2026, 10, 5),
      to: DateTime.utc(2026, 10, 20),
      grouping: AbsenceGrouping.doctor,
    );

    expect(adapter.last!.queryParameters['agruparPor'], 'MEDICO');
  });

  test('un 403 usa el mensaje propio y no el del servidor', () async {
    final (repository, _) = _repository(403, {
      'code': 'ACCESO_DENEGADO',
      'message': 'Sin permiso',
    });

    await expectLater(
      repository.statistics(grouping: AbsenceGrouping.specialty),
      throwsA(
        isA<AbsenceStatisticsException>()
            .having(
              (error) => error.failure,
              'failure',
              AbsenceStatisticsFailure.forbidden,
            )
            .having(
              (error) => error.message,
              'message',
              'Tu cuenta no tiene permiso para ver las estadísticas.',
            ),
      ),
    );
  });
}
