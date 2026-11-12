import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/consultorios/repositories/api_clinic_correction_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_correction_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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

(ApiClinicCorrectionRepository, _StubAdapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiClinicCorrectionRepository(dio), adapter);
}

void main() {
  test('corregir solo nombre hace PATCH con solo nombre', () async {
    final (repository, adapter) = _repository(200, {
      'id': 7,
      'nombre': 'Consultorio 70',
      'ubicacion': 'Piso 1',
    });

    await repository.correct(7, name: 'Consultorio 70');

    expect(adapter.last!.method, 'PATCH');
    expect(adapter.last!.path, '/api/consultorios/7');
    expect(adapter.last!.data, {'nombre': 'Consultorio 70'});
  });

  test('corregir solo ubicación hace PATCH con solo ubicación', () async {
    final (repository, adapter) = _repository(200, {
      'id': 7,
      'nombre': 'Consultorio 7',
      'ubicacion': 'Piso 4',
    });

    await repository.correct(7, location: 'Piso 4');

    expect(adapter.last!.method, 'PATCH');
    expect(adapter.last!.path, '/api/consultorios/7');
    expect(adapter.last!.data, {'ubicacion': 'Piso 4'});
  });

  test('corregir nombre y ubicación envía ambos campos', () async {
    final (repository, adapter) = _repository(200, {
      'id': 7,
      'nombre': 'Consultorio 70',
      'ubicacion': 'Piso 4',
    });

    await repository.correct(7, name: 'Consultorio 70', location: 'Piso 4');

    expect(adapter.last!.data, {
      'nombre': 'Consultorio 70',
      'ubicacion': 'Piso 4',
    });
  });

  test('la respuesta se convierte en Clinic', () async {
    final (repository, _) = _repository(200, {
      'id': 7,
      'nombre': 'Consultorio 70',
      'ubicacion': 'Piso 4',
    });

    final clinic = await repository.correct(
      7,
      name: 'Consultorio 70',
      location: 'Piso 4',
    );

    expect(clinic.id, 7);
    expect(clinic.name, 'Consultorio 70');
    expect(clinic.location, 'Piso 4');
  });

  group('errores por code', () {
    Future<ClinicCorrectionException> failWith(int status, String code) async {
      final (repository, _) = _repository(status, {
        'code': code,
        'message': 'Mensaje del servidor.',
      });
      try {
        await repository.correct(7, name: 'Otro nombre');
      } on ClinicCorrectionException catch (error) {
        return error;
      }
      throw StateError('Tenía que fallar');
    }

    for (final (code, status, failure) in [
      ('CONSULTORIO_NO_ENCONTRADO', 404, ClinicCorrectionFailure.notFound),
      ('CONSULTORIO_DUPLICADO', 409, ClinicCorrectionFailure.duplicate),
      ('VALIDACION', 400, ClinicCorrectionFailure.validation),
      ('ERROR_INTERNO', 500, ClinicCorrectionFailure.other),
    ]) {
      test('$code conserva el mensaje del servidor', () async {
        final error = await failWith(status, code);
        expect(error.failure, failure);
        expect(error.message, 'Mensaje del servidor.');
      });
    }
  });

  test('id cero o negativo falla sin llamar al servidor', () async {
    final (repository, adapter) = _repository(200, {
      'id': 7,
      'nombre': 'Consultorio 70',
      'ubicacion': 'Piso 4',
    });

    for (final id in [0, -3]) {
      await expectLater(
        repository.correct(id, name: 'Consultorio 70'),
        throwsA(
          isA<ClinicCorrectionException>().having(
            (error) => error.failure,
            'failure',
            ClinicCorrectionFailure.notFound,
          ),
        ),
      );
    }
    expect(adapter.last, isNull);
  });
}
