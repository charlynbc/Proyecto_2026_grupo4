import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/models/announcement_edit.dart';
import 'package:agenda_medica/features/novedades/repositories/api_announcements_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Object? body;
  RequestOptions? request;
  String? multipart;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      final bytes = BytesBuilder();
      await for (final chunk in requestStream) {
        bytes.add(chunk);
      }
      multipart = utf8.decode(bytes.takeBytes(), allowMalformed: true);
    }
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        if (body != null) Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiAnnouncementsRepository, _Adapter) _api({int status = 204, Object? body}) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (ApiAnnouncementsRepository(dio), adapter);
}

AnnouncementImageUpload _upload(String name, String subtype, int byte) =>
    AnnouncementImageUpload(
      name: name,
      bytes: Uint8List.fromList([byte]),
      subtype: subtype,
    );

/// Las partes del multipart que se envió, en orden, sin el cierre.
List<String> _parts(_Adapter adapter) {
  final boundary = (adapter.request!.data as FormData).boundary;
  return adapter.multipart!
      .split('--$boundary')
      .where((p) => p.trim().isNotEmpty && p.trim() != '--')
      .toList();
}

Map<String, dynamic> _datos(_Adapter adapter) {
  final part = _parts(adapter).singleWhere((p) => p.contains('name="datos"'));
  final sections = part.split('\r\n\r\n');
  expect(sections.first, contains('content-type: application/json'));
  return jsonDecode(sections.last) as Map<String, dynamic>;
}

Matcher _failsWith(String message) =>
    throwsA(isA<ApiException>().having((e) => e.message, 'message', message));

void main() {
  test('pide PUT /api/admin/anuncios/42 como multipart', () async {
    final (repo, adapter) = _api();

    await repo.update(42, const AnnouncementEdit(title: 'Campaña', text: 'T'));

    expect(adapter.request!.method, 'PUT');
    expect(adapter.request!.path, '/api/admin/anuncios/42');
    expect(adapter.request!.data, isA<FormData>());
  });

  test('sin tocar las imágenes, datos no lleva la lista y no hay otras '
      'partes', () async {
    final (repo, adapter) = _api();

    await repo.update(
      42,
      const AnnouncementEdit(title: 'Campaña', summary: 'Resumen', text: 'T'),
    );

    expect(_datos(adapter), {
      'titulo': 'Campaña',
      'resumen': 'Resumen',
      'texto': 'T',
    });
    expect(_parts(adapter), hasLength(1));
  });

  test(
    'un resumen o un texto en blanco no se envían, y no hay vigencia',
    () async {
      final (repo, adapter) = _api();

      await repo.update(
        42,
        const AnnouncementEdit(
          title: 'Campaña',
          summary: '  ',
          text: '',
          images: [ExistingImageRef(12)],
        ),
      );

      final datos = _datos(adapter);
      expect(datos.keys, unorderedEquals(['titulo', 'imagenes']));
    },
  );

  test(
    'la lista final lleva ids y nombres de archivo en el orden recibido',
    () async {
      final (repo, adapter) = _api();

      await repo.update(
        42,
        AnnouncementEdit(
          title: 'Campaña',
          text: 'T',
          images: [
            const ExistingImageRef(12),
            NewImageRef(_upload('foto.png', 'png', 7)),
            const ExistingImageRef(14),
            NewImageRef(_upload('otra.jpg', 'jpeg', 8)),
          ],
        ),
      );

      expect(_datos(adapter)['imagenes'], [
        {'id': 12},
        {'archivo': 'nueva1'},
        {'id': 14},
        {'archivo': 'nueva2'},
      ]);
      final parts = _parts(adapter);
      expect(parts, hasLength(3));
      expect(parts[1], contains('name="nueva1"'));
      expect(parts[1], contains('filename="foto.png"'));
      expect(parts[1], contains('content-type: image/png'));
      expect(parts[2], contains('name="nueva2"'));
      expect(parts[2], contains('filename="otra.jpg"'));
      expect(parts[2], contains('content-type: image/jpeg'));
    },
  );

  test('una lista vacía se envía como [] para quitar todas', () async {
    final (repo, adapter) = _api();

    await repo.update(
      42,
      const AnnouncementEdit(title: 'Campaña', text: 'T', images: []),
    );

    expect(_datos(adapter)['imagenes'], isEmpty);
    expect(_datos(adapter).containsKey('imagenes'), isTrue);
  });

  for (final (status, code, message) in [
    (400, 'VALIDACION', 'La novedad admite hasta 5 imágenes'),
    (400, 'IMAGEN_INVALIDA', 'Cada imagen admite hasta 5 MB'),
    (404, 'NO_ENCONTRADO', 'Anuncio no encontrado'),
    (
      503,
      'ALMACENAMIENTO_NO_DISPONIBLE',
      'No pudimos guardar las imágenes. Probá de nuevo en unos minutos.',
    ),
  ]) {
    test('un $status $code muestra el mensaje del servidor', () async {
      final (repo, _) = _api(
        status: status,
        body: {'code': code, 'message': message},
      );

      await expectLater(
        repo.update(42, const AnnouncementEdit(title: 'C', text: 'T')),
        _failsWith(message),
      );
    });
  }

  test('sin conexión muestra el mensaje de conexión', () async {
    final dio = Dio()..httpClientAdapter = _Failing();
    addTearDown(() => dio.close(force: true));

    await expectLater(
      ApiAnnouncementsRepository(dio)
          .update(42, const AnnouncementEdit(title: 'C', text: 'T')),
      _failsWith(kApiNoConnectionMessage),
    );
  });
}

class _Failing implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw DioException.connectionError(
    requestOptions: options,
    reason: 'sin red',
  );

  @override
  void close({bool force = false}) {}
}
