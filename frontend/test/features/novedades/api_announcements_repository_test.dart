import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/repositories/api_announcements_repository.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/repositories/announcements_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.status = 200});
  final Object? body;
  final int status;
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

(ApiAnnouncementsRepository, _Adapter) repository(
  Object? body, {
  int status = 200,
}) {
  final adapter = _Adapter(body, status: status);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (ApiAnnouncementsRepository(dio), adapter);
}

Map<String, Object?> card({
  String? title = 'Vacunación',
  String? summary,
  Object? cover,
}) => {
  'id': 42,
  'titulo': title,
  'resumen': summary,
  'publicadoEn': '2026-11-03T12:00:00Z',
  'imagenPortada': cover,
};

void main() {
  for (final (text, images) in [
    ('**Texto**', false),
    (null, true),
    ('**Texto**', true),
  ]) {
    test(
      'publica multipart con texto=${text != null}, imágenes=$images',
      () async {
        final (repo, adapter) = repository({}, status: 201);
        await repo.publish(
          AnnouncementDraft(
            title: 'Jornada de vacunación',
            text: text,
            images: images
                ? [
                    AnnouncementImageUpload(
                      name: 'portada.png',
                      bytes: Uint8List.fromList([1]),
                      subtype: 'png',
                    ),
                    AnnouncementImageUpload(
                      name: 'detalle.jpg',
                      bytes: Uint8List.fromList([2]),
                      subtype: 'jpeg',
                    ),
                  ]
                : [],
          ),
        );
        expect(adapter.request!.method, 'POST');
        expect(adapter.request!.path, '/api/anuncios');
        final body = adapter.multipart!;
        expect(body, contains('name="datos"'));
        expect(body, contains('content-type: application/json'));
        expect(
          body,
          contains(
            jsonEncode({
              'titulo': 'Jornada de vacunación',
              'resumen': null,
              'texto': text,
            }),
          ),
        );
        expect(
          RegExp('name="imagenes"').allMatches(body),
          hasLength(images ? 2 : 0),
        );
        if (images) {
          expect(body, contains('content-type: image/png'));
          expect(body, contains('content-type: image/jpeg'));
          expect(
            body.indexOf('portada.png'),
            lessThan(body.indexOf('detalle.jpg')),
          );
        }
      },
    );
  }

  test('publicación conserva el rechazo de permisos del servidor', () async {
    final (repo, _) = repository({'message': 'Acceso denegado'}, status: 403);
    await expectLater(
      repo.publish(const AnnouncementDraft(title: 'Título', text: 'Texto')),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Acceso denegado',
        ),
      ),
    );
  });

  test(
    'listado solicita diez por página y usa el total para avanzar',
    () async {
      final (repo, adapter) = repository({
        'items': [card()],
        'page': 1,
        'size': 10,
        'total': 23,
      });
      final result = await repo.list(page: 1);
      expect(adapter.request!.path, '/api/anuncios');
      expect(adapter.request!.queryParameters, {'page': 1, 'size': 10});
      expect(result.page, 1);
      expect(result.total, 23);
      expect(result.hasNext, isTrue);
      expect(result.items.single.id, 42);
    },
  );

  test('última página no permite avanzar', () async {
    final (repo, _) = repository({
      'items': [card()],
      'page': 2,
      'size': 10,
      'total': 21,
    });
    expect((await repo.list(page: 2)).hasNext, isFalse);
  });

  test('listado vacío conserva la primera página', () async {
    final (repo, _) = repository({
      'items': [],
      'page': 0,
      'size': 10,
      'total': 0,
    });
    final result = await repo.list();
    expect(result.items, isEmpty);
    expect(result.hasNext, isFalse);
  });

  test('página negativa no consulta la API', () async {
    final (repo, adapter) = repository(null);
    await expectLater(repo.list(page: -1), throwsArgumentError);
    expect(adapter.request, isNull);
  });

  for (final body in [
    null,
    {
      'items': List.generate(11, (_) => card()),
      'page': 0,
      'size': 10,
      'total': 11,
    },
    {'items': [], 'page': 1, 'size': 10, 'total': 0},
    {'items': [], 'page': 0, 'size': 20, 'total': 0},
    {'items': [], 'page': 0, 'size': 10, 'total': -1},
  ]) {
    test('listado rechaza una página inconsistente: $body', () async {
      final (repo, _) = repository(body);
      await expectLater(repo.list(), throwsA(isA<ApiException>()));
    });
  }

  test('listado conserva un error de almacenamiento', () async {
    final (repo, _) = repository({
      'code': 'ALMACENAMIENTO_NO_DISPONIBLE',
      'message': 'Almacenamiento no disponible',
    }, status: 503);
    await expectLater(
      repo.list(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Almacenamiento no disponible',
        ),
      ),
    );
  });

  Map<String, Object?> detail({
    Object? images = const [],
    String? text = '**Texto**',
  }) => {
    'id': 42,
    'titulo': null,
    'resumen': null,
    'texto': text,
    'publicadoEn': '2026-11-03T12:00:00Z',
    'imagenes': images,
  };

  test('detalle usa GET #67 y conserva Markdown y campos opcionales', () async {
    final (repo, adapter) = repository(detail());
    final result = await repo.detail(42);
    expect(adapter.request!.path, '/api/anuncios/42');
    expect(adapter.request!.method, 'GET');
    expect(adapter.request!.queryParameters, isEmpty);
    expect(result.title, isNull);
    expect(result.summary, isNull);
    expect(result.text, '**Texto**');
    expect(result.images, isEmpty);
  });

  test('detalle solo imágenes conserva el orden del servidor', () async {
    final (repo, _) = repository(
      detail(
        text: null,
        images: [
          {
            'id': 101,
            'orden': 0,
            'url': 'https://example.org/1?token=temporal',
          },
          {
            'id': 102,
            'orden': 1,
            'url': 'https://example.org/2?token=temporal',
          },
        ],
      ),
    );
    final result = await repo.detail(42);
    expect(result.text, isNull);
    expect(result.images.map((image) => image.id), [101, 102]);
    expect(result.images.first.url, contains('token=temporal'));
  });

  test('detalle inexistente distingue NO_ENCONTRADO', () async {
    final (repo, _) = repository({
      'code': 'NO_ENCONTRADO',
      'message': 'Anuncio no encontrado',
    }, status: 404);
    await expectLater(
      repo.detail(42),
      throwsA(isA<AnnouncementNotFoundException>()),
    );
  });

  test('id inválido no consulta la red', () async {
    final (repo, adapter) = repository(detail());
    await expectLater(
      repo.detail(0),
      throwsA(isA<AnnouncementNotFoundException>()),
    );
    expect(adapter.request, isNull);
  });

  for (final status in [401, 503]) {
    test(
      'detalle conserva error HTTP $status para el flujo compartido',
      () async {
        final (repo, _) = repository({
          'code': status == 401
              ? 'NO_AUTENTICADO'
              : 'ALMACENAMIENTO_NO_DISPONIBLE',
          'message': 'Error del servidor',
        }, status: status);
        await expectLater(
          repo.detail(42),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Error del servidor',
            ),
          ),
        );
      },
    );
  }

  for (final body in [
    null,
    [],
    detail()..['id'] = 43,
    detail()..['publicadoEn'] = 'inválida',
    detail(images: null),
    detail(
      images: [
        {'id': 1, 'orden': 0, 'url': ''},
      ],
    ),
  ]) {
    test('rechaza detalle incompleto o de otra novedad: $body', () async {
      final (repo, _) = repository(body);
      await expectLater(repo.detail(42), throwsA(isA<ApiException>()));
    });
  }

  test(
    'pide solo las cinco últimas tarjetas y lee la portada firmada',
    () async {
      final (repo, adapter) = repository({
        'items': [
          card(
            summary: 'Comienza el lunes',
            cover: {
              'id': 101,
              'orden': 0,
              'url': 'https://example.org/portada?token=temporal',
            },
          ),
        ],
        'page': 0,
        'size': 5,
        'total': 12,
      });
      final items = await repo.latest();
      expect(adapter.request!.path, '/api/anuncios');
      expect(adapter.request!.method, 'GET');
      expect(adapter.request!.queryParameters, {'page': 0, 'size': 5});
      expect(items.single.id, 42);
      expect(items.single.displayTitle, 'Vacunación');
      expect(items.single.summary, 'Comienza el lunes');
      expect(items.single.publishedAt, DateTime.utc(2026, 11, 3, 12));
      expect(
        items.single.coverUrl,
        'https://example.org/portada?token=temporal',
      );
    },
  );

  test('admite título antiguo, resumen y portada nulos', () async {
    final (repo, _) = repository({
      'items': [card(title: null)],
    });
    final item = (await repo.latest()).single;
    expect(item.displayTitle, 'Novedad de la mutualista');
    expect(item.summary, isNull);
    expect(item.coverUrl, isNull);
  });

  test('una página vacía produce la lista vacía', () async {
    final (repo, _) = repository({'items': []});
    expect(await repo.latest(), isEmpty);
  });

  for (final body in [
    null,
    [],
    <String, Object?>{},
    {'items': null},
    {
      'items': [card()..['publicadoEn'] = 'inválida'],
    },
    {
      'items': [card()..['id'] = 0],
    },
    {
      'items': [card(cover: <String, Object?>{})],
    },
  ]) {
    test(
      'convierte una respuesta incompleta o inválida en error de API: $body',
      () async {
        final (repo, _) = repository(body);
        await expectLater(repo.latest(), throwsA(isA<ApiException>()));
      },
    );
  }

  test(
    'conserva el error del backend y permite un reintento posterior',
    () async {
      final (repo, _) = repository({
        'code': 'ALMACENAMIENTO_NO_DISPONIBLE',
        'message': 'Almacenamiento no disponible',
      }, status: 503);
      await expectLater(
        repo.latest(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Almacenamiento no disponible',
          ),
        ),
      );
    },
  );
}
