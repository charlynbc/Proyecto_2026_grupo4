import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/repositories/api_specialty_import_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/specialty_import_csv.dart';

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

(ApiSpecialtyImportRepository, _StubAdapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiSpecialtyImportRepository(dio), adapter);
}

Map<String, Object?> _row(
  int number, {
  String? name,
  bool? requiresReferral,
  String? error,
}) => {
  'numero': number,
  'nombre': name,
  'requierePase': requiresReferral,
  'error': error,
};

final _valid = _row(2, name: 'Neurología', requiresReferral: true);
final _bad = _row(3, error: 'La fila debe tener exactamente 2 columnas.');

void main() {
  test(
    'previsualizar hace POST multipart a la ruta de previsualizar',
    () async {
      final (repository, adapter) = _repository(200, {
        'total': 2,
        'validas': 1,
        'invalidas': 1,
        'filas': [_valid, _bad],
        'errores': [_bad],
      });

      await repository.preview(
        specialtyCsvFile('nombre,requiere_pase\nA,si\n', name: 'e.csv'),
      );

      expect(adapter.last!.method, 'POST');
      expect(
        adapter.last!.path,
        '/api/especialidades/importaciones/previsualizar',
      );
      expect(adapter.sentBody, contains('name="archivo"'));
      expect(adapter.sentBody, contains('filename="e.csv"'));
      expect(adapter.sentBody, contains('nombre,requiere_pase\nA,si\n'));
    },
  );

  test('confirmar hace POST multipart a la ruta de confirmar', () async {
    final (repository, adapter) = _repository(200, {
      'total': 2,
      'importadas': 1,
      'rechazadas': 1,
      'filas': [_valid, _bad],
      'errores': [_bad],
    });

    await repository.confirm(
      specialtyCsvFile('nombre,requiere_pase\nA,si\n', name: 'e.csv'),
    );

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/especialidades/importaciones/confirmar');
    expect(adapter.sentBody, contains('name="archivo"'));
    expect(adapter.sentBody, contains('nombre,requiere_pase\nA,si\n'));
  });

  test('la previsualización se convierte en el modelo', () async {
    final (repository, _) = _repository(200, {
      'total': 2,
      'validas': 1,
      'invalidas': 1,
      'filas': [_valid, _bad],
      'errores': [_bad],
    });

    final preview = await repository.preview(specialtyImportFile());

    expect(preview.total, 2);
    expect(preview.valid, 1);
    expect(preview.invalid, 1);
    expect(preview.rows.map((r) => r.number), [2, 3]);
    expect(preview.errors.map((r) => r.number), [3]);
    final valid = preview.rows.first;
    expect(valid.name, 'Neurología');
    expect(valid.requiresReferral, isTrue);
    expect(valid.error, isNull);
    final bad = preview.errors.single;
    expect(bad.name, isNull);
    expect(bad.requiresReferral, isNull);
    expect(bad.error, 'La fila debe tener exactamente 2 columnas.');
  });

  test('el resultado de confirmar se convierte en el modelo', () async {
    final (repository, _) = _repository(200, {
      'total': 2,
      'importadas': 1,
      'rechazadas': 1,
      'filas': [_valid, _bad],
      'errores': [_bad],
    });

    final result = await repository.confirm(specialtyImportFile());

    expect(result.total, 2);
    expect(result.imported, 1);
    expect(result.rejected, 1);
    expect(result.rows, hasLength(2));
    expect(result.errors.single.number, 3);
    expect(result.errors.single.name, isNull);
  });

  test('si confirmar no trae total, es importadas más rechazadas', () async {
    final (repository, _) = _repository(200, {
      'importadas': 1,
      'rechazadas': 2,
      'filas': [_valid, _bad, _bad],
      'errores': [_bad, _bad],
    });

    final result = await repository.confirm(specialtyImportFile());

    expect(result.total, 3);
  });

  test(
    'un 400 CSV_INVALIDO lanza ApiException con el mensaje del servidor',
    () async {
      final (repository, _) = _repository(400, {
        'code': 'CSV_INVALIDO',
        'message': 'El archivo supera el tamaño máximo permitido (1 MB)',
      });

      for (final call in [
        () => repository.preview(specialtyImportFile()),
        () => repository.confirm(specialtyImportFile()),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'El archivo supera el tamaño máximo permitido (1 MB)',
            ),
          ),
        );
      }
    },
  );

  test('una respuesta mal formada es el error genérico', () async {
    final (repository, _) = _repository(200, {'total': 'muchas'});

    await expectLater(
      repository.preview(specialtyImportFile()),
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
