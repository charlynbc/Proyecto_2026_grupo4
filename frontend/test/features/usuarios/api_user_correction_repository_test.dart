import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/usuarios/repositories/api_user_correction_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_correction_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Stub implements HttpClientAdapter {
  _Stub(this.status, this.body);

  final int status;
  final Object? body;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

Map<String, dynamic> _row() => {
  'id': 12,
  'ci': '34567894',
  'nombre': 'Sofia Elena',
  'apellido': 'Socia',
  'fechaNacimiento': '1985-06-06',
  'rol': 'MEDICO',
  'correo': 'sofia@ejemplo.invalid',
  'telefono1': '099111222',
  'telefono2': null,
  'direccion': 'Calle Falsa 123',
  'especialidadIds': [3, 7],
  'estado': 'ACTIVA',
  'activada': true,
};

(ApiUserCorrectionRepository, _Stub) _repo(int status, Object? body) {
  final stub = _Stub(status, body);
  return (ApiUserCorrectionRepository(Dio()..httpClientAdapter = stub), stub);
}

Future<UserCorrectionException> _failure(Future<Object?> call) async {
  try {
    await call;
  } on UserCorrectionException catch (e) {
    return e;
  }
  throw StateError('Se esperaba un UserCorrectionException');
}

void main() {
  group('fetch', () {
    test('pide GET /api/usuarios/{id} y lee el detalle', () async {
      final (repo, stub) = _repo(200, _row());

      final detail = await repo.fetch(12);

      expect(stub.requests.single.method, 'GET');
      expect(stub.requests.single.path, '/api/usuarios/12');
      expect(detail.id, 12);
      expect(detail.specialtyIds, [3, 7]);
      expect(detail.phone2, isNull);
    });

    test('un id que no es positivo no llama al servidor', () async {
      final (repo, stub) = _repo(200, _row());

      for (final id in [0, -3]) {
        final error = await _failure(repo.fetch(id));
        expect(error.failure, UserCorrectionFailure.notFound);
      }
      expect(stub.requests, isEmpty);
    });

    test('un 404 USUARIO_NO_ENCONTRADO es notFound', () async {
      final (repo, _) = _repo(404, {
        'code': 'USUARIO_NO_ENCONTRADO',
        'message': 'No existe la cuenta.',
      });

      final error = await _failure(repo.fetch(12));

      expect(error.failure, UserCorrectionFailure.notFound);
      expect(error.message, 'No existe la cuenta.');
    });

    test(
      'un 403 muestra el mensaje del servidor como error genérico',
      () async {
        final (repo, _) = _repo(403, {
          'code': 'ACCESO_DENEGADO',
          'message': 'No tenés permiso.',
        });

        final error = await _failure(repo.fetch(12));

        expect(error.failure, UserCorrectionFailure.other);
        expect(error.message, 'No tenés permiso.');
      },
    );

    test('una respuesta con un tipo incorrecto es el error genérico', () async {
      final (repo, _) = _repo(200, {..._row(), 'id': '12'});

      final error = await _failure(repo.fetch(12));

      expect(error.failure, UserCorrectionFailure.other);
      expect(error.message, kApiGenericMessage);
    });
  });

  group('correct: qué se manda', () {
    test('pide PATCH /api/usuarios/{id} y devuelve el detalle', () async {
      final (repo, stub) = _repo(200, _row());

      final detail = await repo.correct(
        12,
        const AccountCorrection(email: 'nuevo@ejemplo.org'),
      );

      expect(stub.requests.single.method, 'PATCH');
      expect(stub.requests.single.path, '/api/usuarios/12');
      expect(detail.id, 12);
    });

    test('solo viajan los campos que cambiaron', () async {
      final (repo, stub) = _repo(200, _row());

      await repo.correct(
        12,
        const AccountCorrection(email: 'nuevo@ejemplo.org'),
      );

      expect(stub.requests.single.data, {'correo': 'nuevo@ejemplo.org'});
    });

    test('cada campo viaja con su nombre del contrato', () async {
      final (repo, stub) = _repo(200, _row());

      await repo.correct(
        12,
        AccountCorrection(
          ci: '45678905',
          firstName: 'Sofía',
          lastName: 'Soca',
          birthDate: DateTime.utc(1985, 6, 7),
          email: 'sofia@ejemplo.org',
          phone1: '098123456',
          phone2: const TextChange.set('099654321'),
          address: const TextChange.set('Calle Nueva 45'),
          specialtyIds: const [3],
        ),
      );

      expect(stub.requests.single.data, {
        'ci': '45678905',
        'nombre': 'Sofía',
        'apellido': 'Soca',
        'fechaNacimiento': '1985-06-07',
        'correo': 'sofia@ejemplo.org',
        'telefono1': '098123456',
        'telefono2': '099654321',
        'direccion': 'Calle Nueva 45',
        'especialidadIds': [3],
      });
    });

    test(
      'borrar el teléfono 2 manda null, que no es lo mismo que omitirlo',
      () async {
        final (repo, stub) = _repo(200, _row());

        await repo.correct(
          12,
          const AccountCorrection(phone2: TextChange.clear()),
        );

        final data = stub.requests.single.data as Map<String, dynamic>;
        expect(data.containsKey('telefono2'), isTrue);
        expect(data['telefono2'], isNull);
        expect(data.containsKey('direccion'), isFalse);
        expect(data.length, 1);
      },
    );

    test('borrar la dirección manda null y deja el resto sin tocar', () async {
      final (repo, stub) = _repo(200, _row());

      await repo.correct(
        12,
        const AccountCorrection(address: TextChange.clear()),
      );

      final data = stub.requests.single.data as Map<String, dynamic>;
      expect(data.containsKey('direccion'), isTrue);
      expect(data['direccion'], isNull);
      expect(data.containsKey('telefono2'), isFalse);
      expect(data.length, 1);
    });

    test('sin cambios ni llama al servidor', () async {
      final (repo, stub) = _repo(200, _row());

      final error = await _failure(repo.correct(12, const AccountCorrection()));

      expect(error.failure, UserCorrectionFailure.validation);
      expect(stub.requests, isEmpty);
    });

    test('un id que no es positivo no llama al servidor', () async {
      final (repo, stub) = _repo(200, _row());

      final error = await _failure(
        repo.correct(0, const AccountCorrection(phone1: '099111222')),
      );

      expect(error.failure, UserCorrectionFailure.notFound);
      expect(stub.requests, isEmpty);
    });
  });

  group('correct: errores por code', () {
    for (final (status, code, failure) in [
      (400, 'VALIDACION', UserCorrectionFailure.validation),
      (400, 'CI_INVALIDA', UserCorrectionFailure.invalidCi),
      (404, 'USUARIO_NO_ENCONTRADO', UserCorrectionFailure.notFound),
      (409, 'CI_EN_USO', UserCorrectionFailure.ciInUse),
      (409, 'ESPECIALIDAD_EN_USO', UserCorrectionFailure.specialtyInUse),
      (500, 'OTRO_CODIGO', UserCorrectionFailure.other),
    ]) {
      test('$status $code es $failure y conserva el mensaje', () async {
        final (repo, _) = _repo(status, {
          'code': code,
          'message': 'Mensaje de $code',
        });

        final error = await _failure(
          repo.correct(12, const AccountCorrection(phone1: '099111222')),
        );

        expect(error.failure, failure);
        expect(error.message, 'Mensaje de $code');
      });
    }

    test('una respuesta con un tipo incorrecto es el error genérico', () async {
      final (repo, _) = _repo(200, {..._row(), 'activada': 'si'});

      final error = await _failure(
        repo.correct(12, const AccountCorrection(phone1: '099111222')),
      );

      expect(error.failure, UserCorrectionFailure.other);
      expect(error.message, kApiGenericMessage);
    });
  });
}
