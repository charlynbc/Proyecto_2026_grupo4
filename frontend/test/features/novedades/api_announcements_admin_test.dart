import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/repositories/api_announcements_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, this.status);
  final Object? body;
  final int status;
  RequestOptions? request;
  String? sent;

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
      sent = utf8.decode(bytes.takeBytes());
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

(ApiAnnouncementsRepository, _Adapter) _api(Object? body, {int status = 200}) {
  final adapter = _Adapter(body, status);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (ApiAnnouncementsRepository(dio), adapter);
}

Map<String, Object?> _row(int id, String estado, {Object? posicion}) => {
  'id': id,
  'titulo': 'Novedad $id',
  'publicadoEn': '2026-11-03T12:00:00Z',
  'vigenteDesde': null,
  'vigenteHasta': '2026-12-01T00:00:00-03:00',
  'estado': estado,
  'posicion': posicion,
};

Matcher _failsWith(String message) =>
    throwsA(isA<ApiException>().having((e) => e.message, 'message', message));

void main() {
  group('listado de administración', () {
    test('pide GET /api/admin/anuncios y conserva el orden recibido', () async {
      final (repo, adapter) = _api([
        _row(9, 'VENCIDO'),
        _row(5, 'PROGRAMADO'),
        _row(7, 'VIGENTE', posicion: 2),
      ]);

      final items = await repo.adminList();

      expect(adapter.request!.method, 'GET');
      expect(adapter.request!.path, '/api/admin/anuncios');
      expect(items.map((i) => i.id), [9, 5, 7]);
      expect(items.map((i) => i.status), [
        AnnouncementStatus.expired,
        AnnouncementStatus.scheduled,
        AnnouncementStatus.active,
      ]);
      expect(items[2].position, 2);
      expect(items[0].position, isNull);
    });

    test('una lista vacía es válida', () async {
      final (repo, _) = _api([]);

      expect(await repo.adminList(), isEmpty);
    });

    for (final body in [
      null,
      <String, Object?>{},
      [_row(1, 'ELIMINADO')],
      [
        {..._row(1, 'VIGENTE'), 'id': 0},
      ],
    ]) {
      test('una respuesta inválida es un error de API: $body', () async {
        final (repo, _) = _api(body);

        await expectLater(repo.adminList(), throwsA(isA<ApiException>()));
      });
    }

    test('el 403 muestra el mensaje del servidor', () async {
      final (repo, _) = _api({
        'code': 'ACCESO_DENEGADO',
        'message': 'No tenés permiso para esto',
      }, status: 403);

      await expectLater(
        repo.adminList(),
        _failsWith('No tenés permiso para esto'),
      );
    });
  });

  group('cambiar la vigencia', () {
    test('PUT con inicio y fin, ambos con desfase -03:00', () async {
      final (repo, adapter) = _api(null, status: 204);

      await repo.updateValidity(
        42,
        from: DateTime.utc(2026, 12, 1, 3),
        until: DateTime.utc(2027, 1, 1, 2, 59),
      );

      expect(adapter.request!.method, 'PUT');
      expect(adapter.request!.path, '/api/admin/anuncios/42/vigencia');
      expect(jsonDecode(adapter.sent!), {
        'vigenteDesde': '2026-12-01T00:00:00-03:00',
        'vigenteHasta': '2026-12-31T23:59:00-03:00',
      });
    });

    test('sin inicio manda vigenteDesde en null y el fin', () async {
      final (repo, adapter) = _api(null, status: 204);

      await repo.updateValidity(7, until: DateTime.utc(2027, 1, 1, 3));

      expect(jsonDecode(adapter.sent!), {
        'vigenteDesde': null,
        'vigenteHasta': '2027-01-01T00:00:00-03:00',
      });
    });

    test('un 400 muestra el mensaje del servidor', () async {
      final (repo, _) = _api({
        'code': 'VALIDACION',
        'message': 'El fin debe ser posterior al inicio',
      }, status: 400);

      await expectLater(
        repo.updateValidity(7, until: DateTime.utc(2027, 1, 1, 3)),
        _failsWith('El fin debe ser posterior al inicio'),
      );
    });

    test('un 404 muestra el mensaje del servidor', () async {
      final (repo, _) = _api({
        'code': 'NO_ENCONTRADO',
        'message': 'Anuncio no encontrado',
      }, status: 404);

      await expectLater(
        repo.updateValidity(7, until: DateTime.utc(2027, 1, 1, 3)),
        _failsWith('Anuncio no encontrado'),
      );
    });
  });

  group('carrusel del administrador', () {
    test('GET lee la selección con sus huecos', () async {
      final (repo, adapter) = _api({
        'posiciones': [
          {'posicion': 1, 'anuncioId': 42},
          {'posicion': 3, 'anuncioId': 56},
        ],
      });

      final slots = await repo.adminCarousel();

      expect(adapter.request!.method, 'GET');
      expect(adapter.request!.path, '/api/admin/carrusel');
      expect(slots.map((s) => (s.position, s.announcementId)), [
        (1, 42),
        (3, 56),
      ]);
    });

    test('sin selección la lista es vacía', () async {
      final (repo, _) = _api({'posiciones': []});

      expect(await repo.adminCarousel(), isEmpty);
    });

    for (final body in [
      null,
      [],
      <String, Object?>{},
      {'posiciones': null},
      {
        'posiciones': [
          {'posicion': 'a', 'anuncioId': 1},
        ],
      },
    ]) {
      test('una respuesta inválida es un error de API: $body', () async {
        final (repo, _) = _api(body);

        await expectLater(repo.adminCarousel(), throwsA(isA<ApiException>()));
      });
    }

    test('PUT manda la selección completa, sin rellenar huecos', () async {
      final (repo, adapter) = _api({
        'posiciones': [
          {'posicion': 1, 'anuncioId': 42},
          {'posicion': 3, 'anuncioId': 56},
        ],
      });

      final saved = await repo.saveCarousel(const [
        CarouselSlot(position: 1, announcementId: 42),
        CarouselSlot(position: 3, announcementId: 56),
      ]);

      expect(adapter.request!.method, 'PUT');
      expect(adapter.request!.path, '/api/admin/carrusel');
      expect(jsonDecode(adapter.sent!), {
        'posiciones': [
          {'posicion': 1, 'anuncioId': 42},
          {'posicion': 3, 'anuncioId': 56},
        ],
      });
      expect(saved.map((s) => s.position), [1, 3]);
    });

    test('guardar una selección vacía manda posiciones vacías', () async {
      final (repo, adapter) = _api({'posiciones': []});

      await repo.saveCarousel(const []);

      expect(jsonDecode(adapter.sent!), {'posiciones': []});
    });

    test('un 400 muestra el mensaje del servidor', () async {
      final (repo, _) = _api({
        'code': 'VALIDACION',
        'message': 'Posición o anuncio repetido o inválido',
      }, status: 400);

      await expectLater(
        repo.saveCarousel(const [
          CarouselSlot(position: 1, announcementId: 42),
        ]),
        _failsWith('Posición o anuncio repetido o inválido'),
      );
    });

    test('un 404 muestra el mensaje del servidor', () async {
      final (repo, _) = _api({
        'code': 'NO_ENCONTRADO',
        'message': 'Anuncio no encontrado',
      }, status: 404);

      await expectLater(
        repo.saveCarousel(const [
          CarouselSlot(position: 1, announcementId: 42),
        ]),
        _failsWith('Anuncio no encontrado'),
      );
    });
  });

  group('eliminar', () {
    test('DELETE y el 202 es éxito', () async {
      final (repo, adapter) = _api(null, status: 202);

      await repo.delete(42);

      expect(adapter.request!.method, 'DELETE');
      expect(adapter.request!.path, '/api/admin/anuncios/42');
    });

    test('un 404 muestra el mensaje del servidor', () async {
      final (repo, _) = _api({
        'code': 'NO_ENCONTRADO',
        'message': 'Anuncio no encontrado',
      }, status: 404);

      await expectLater(repo.delete(42), _failsWith('Anuncio no encontrado'));
    });

    test('un id inválido no llega a la red', () async {
      final (repo, adapter) = _api(null, status: 202);

      await expectLater(repo.delete(0), throwsA(isA<ApiException>()));
      expect(adapter.request, isNull);
    });
  });
}
