import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/usuarios/repositories/api_user_import_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/user_import_csv.dart';

/// Adaptador de dio que anota el pedido y responde con lo indicado.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Object? body;
  RequestOptions? last;

  /// El cuerpo que se mandó, como texto.
  String sentBody = '';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      sentBody = utf8.decode(chunks.expand((c) => c).toList());
    }
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

(ApiUserImportRepository, _StubAdapter) _repository(int status, Object? body) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiUserImportRepository(dio), adapter);
}

/// El cuerpo multipart que se mandó, como texto.
Future<String> _sentBody(_StubAdapter adapter) async => adapter.sentBody;

Map<String, Object?> _row(
  int number, {
  String? ci,
  String? firstName,
  String? lastName,
  String? role,
  String? error,
}) => {
  'numero': number,
  'ci': ci,
  'nombre': firstName,
  'apellido': lastName,
  'rol': role,
  'error': error,
};

final _valid = _row(
  2,
  ci: '30000010',
  firstName: 'Julia',
  lastName: 'Ferrari',
  role: 'SOCIO',
);
final _malformed = _row(
  3,
  error: 'La fila debe tener exactamente 10 columnas.',
);
final _badCi = _row(
  4,
  ci: '30000033',
  firstName: 'Sara',
  lastName: 'Lima',
  role: 'SOCIO',
  error: 'La CI no es valida',
);

void main() {
  test(
    'previsualizar hace POST multipart a la ruta de previsualizar',
    () async {
      final (repository, adapter) = _repository(200, {
        'total': 3,
        'validas': 1,
        'invalidas': 2,
        'filas': [_valid, _malformed, _badCi],
        'errores': [_malformed, _badCi],
      });

      await repository.preview(csvFile('ci,nombre\n1,2\n', name: 'u.csv'));

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/usuarios/importaciones/previsualizar');
      final body = await _sentBody(adapter);
      expect(body, contains('name="archivo"'));
      expect(body, contains('filename="u.csv"'));
      expect(body, contains('ci,nombre\n1,2\n'));
    },
  );

  test('confirmar hace POST multipart a la ruta de confirmar', () async {
    final (repository, adapter) = _repository(200, {
      'total': 3,
      'importadas': 1,
      'rechazadas': 2,
      'filas': [_valid, _malformed, _badCi],
      'errores': [_malformed, _badCi],
    });

    await repository.confirm(csvFile('ci,nombre\n1,2\n', name: 'u.csv'));

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/usuarios/importaciones/confirmar');
    final body = await _sentBody(adapter);
    expect(body, contains('name="archivo"'));
    expect(body, contains('ci,nombre\n1,2\n'));
  });

  test(
    'la previsualización se convierte en el modelo, con datos nulos',
    () async {
      final (repository, _) = _repository(200, {
        'total': 3,
        'validas': 1,
        'invalidas': 2,
        'filas': [_valid, _malformed, _badCi],
        'errores': [_malformed, _badCi],
      });

      final preview = await repository.preview(userImportFile());

      expect(preview.total, 3);
      expect(preview.valid, 1);
      expect(preview.invalid, 2);
      expect(preview.rows.map((r) => r.number), [2, 3, 4]);
      expect(preview.errors.map((r) => r.number), [3, 4]);
      final valid = preview.rows.first;
      expect(valid.ci, '30000010');
      expect(valid.firstName, 'Julia');
      expect(valid.lastName, 'Ferrari');
      expect(valid.role, 'SOCIO');
      expect(valid.error, isNull);
      final malformed = preview.errors.first;
      expect(malformed.ci, isNull);
      expect(malformed.firstName, isNull);
      expect(malformed.lastName, isNull);
      expect(malformed.role, isNull);
      expect(malformed.error, 'La fila debe tener exactamente 10 columnas.');
      expect(preview.errors.last.error, 'La CI no es valida');
    },
  );

  test('el resultado de confirmar se convierte en el modelo', () async {
    final (repository, _) = _repository(200, {
      'total': 3,
      'importadas': 1,
      'rechazadas': 2,
      'filas': [_valid, _malformed, _badCi],
      'errores': [_malformed, _badCi],
    });

    final result = await repository.confirm(userImportFile());

    expect(result.total, 3);
    expect(result.imported, 1);
    expect(result.rejected, 2);
    expect(result.rows, hasLength(3));
    expect(result.errors.map((r) => r.number), [3, 4]);
    expect(result.errors.first.ci, isNull);
  });

  test('si confirmar no trae total, es importadas más rechazadas', () async {
    final (repository, _) = _repository(200, {
      'importadas': 1,
      'rechazadas': 2,
      'filas': [_valid, _malformed, _badCi],
      'errores': [_malformed, _badCi],
    });

    final result = await repository.confirm(userImportFile());

    expect(result.total, 3);
  });

  test(
    'un 400 CSV_INVALIDO lanza ApiException con el mensaje del servidor',
    () async {
      final (repository, _) = _repository(400, {
        'code': 'CSV_INVALIDO',
        'message': 'El archivo supera el tamaño máximo permitido (1 MB)',
      });

      await expectLater(
        repository.preview(userImportFile()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'El archivo supera el tamaño máximo permitido (1 MB)',
          ),
        ),
      );
      await expectLater(
        repository.confirm(userImportFile()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'El archivo supera el tamaño máximo permitido (1 MB)',
          ),
        ),
      );
    },
  );

  test('una respuesta mal formada es el error genérico', () async {
    final (repository, _) = _repository(200, {'total': 'muchas'});

    await expectLater(
      repository.preview(userImportFile()),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          kApiGenericMessage,
        ),
      ),
    );
  });
}
