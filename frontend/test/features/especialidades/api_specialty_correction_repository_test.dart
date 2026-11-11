import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/repositories/api_specialty_correction_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_correction_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador de dio que anota el pedido y responde con lo indicado.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

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

(ApiSpecialtyCorrectionRepository, _StubAdapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiSpecialtyCorrectionRepository(dio), adapter);
}

const _okBody = {
  'id': 12,
  'nombre': 'Cardiología clínica',
  'requierePase': false,
};

Matcher _failure(SpecialtyCorrectionFailure failure, String message) =>
    isA<SpecialtyCorrectionException>()
        .having((e) => e.failure, 'failure', failure)
        .having((e) => e.message, 'message', message);

void main() {
  test('solo el nombre: PATCH a la especialidad con solo nombre', () async {
    final (repository, adapter) = _repository(200, _okBody);

    await repository.correct(12, name: 'Cardiología clínica');

    expect(adapter.last!.method, 'PATCH');
    expect(adapter.last!.path, '/api/especialidades/12');
    expect(adapter.last!.data, {'nombre': 'Cardiología clínica'});
  });

  test('solo el pase: el cuerpo lleva solo requierePase', () async {
    final (repository, adapter) = _repository(200, _okBody);

    await repository.correct(12, requiresReferral: false);

    expect(adapter.last!.data, {'requierePase': false});
  });

  test('con los dos campos el cuerpo lleva ambos', () async {
    final (repository, adapter) = _repository(200, _okBody);

    await repository.correct(
      12,
      name: 'Cardiología clínica',
      requiresReferral: true,
    );

    expect(adapter.last!.data, {
      'nombre': 'Cardiología clínica',
      'requierePase': true,
    });
  });

  test('la respuesta se convierte en la especialidad corregida', () async {
    final (repository, _) = _repository(200, _okBody);

    final specialty = await repository.correct(12, requiresReferral: false);

    expect(specialty.id, 12);
    expect(specialty.name, 'Cardiología clínica');
    expect(specialty.requiresReferral, isFalse);
  });

  test('una respuesta mal formada es el error genérico', () async {
    final (repository, _) = _repository(200, {'id': 12});

    await expectLater(
      repository.correct(12, requiresReferral: false),
      throwsA(_failure(SpecialtyCorrectionFailure.other, kApiGenericMessage)),
    );
  });

  final errors = <(int, String, SpecialtyCorrectionFailure)>[
    (404, 'ESPECIALIDAD_NO_ENCONTRADA', SpecialtyCorrectionFailure.notFound),
    (409, 'ESPECIALIDAD_DUPLICADA', SpecialtyCorrectionFailure.duplicate),
    (400, 'VALIDACION', SpecialtyCorrectionFailure.validation),
    (500, 'ERROR_INTERNO', SpecialtyCorrectionFailure.other),
  ];
  for (final (status, code, failure) in errors) {
    test('$status $code da $failure con el mensaje del servidor', () async {
      final (repository, _) = _repository(status, {
        'code': code,
        'message': 'Texto del servidor.',
      });

      await expectLater(
        repository.correct(12, name: 'Cardiología clínica'),
        throwsA(_failure(failure, 'Texto del servidor.')),
      );
    });
  }

  for (final id in [0, -3]) {
    test('el id $id es no encontrada y no hace ninguna llamada', () async {
      final (repository, adapter) = _repository(200, _okBody);

      await expectLater(
        repository.correct(id, name: 'Cardiología clínica'),
        throwsA(
          _failure(
            SpecialtyCorrectionFailure.notFound,
            'No se encontró la especialidad.',
          ),
        ),
      );
      expect(adapter.last, isNull);
    });
  }
}
