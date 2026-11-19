import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/repositories/announcements_repository.dart';
import 'package:agenda_medica/features/novedades/repositories/api_announcements_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, this.status);
  final Object? body;
  final int status;
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

(ApiAnnouncementsRepository, _Adapter) _api(Object? body, {int status = 200}) {
  final adapter = _Adapter(body, status);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (ApiAnnouncementsRepository(dio), adapter);
}

Map<String, Object?> _body({int id = 42}) => {
  'id': id,
  'titulo': 'Campaña de vacunación',
  'resumen': null,
  'texto': '**Comienza** el lunes',
  'publicadoEn': '2026-11-01T10:00:00-03:00',
  'vigenteDesde': null,
  'vigenteHasta': '2026-11-10T00:00:00-03:00',
  'estado': 'VENCIDO',
  'posicion': null,
  'imagenes': [
    {'id': 101, 'orden': 0, 'url': 'https://almacen.example/101'},
  ],
};

void main() {
  test('pide GET /api/admin/anuncios/42, no el endpoint público', () async {
    final (repo, adapter) = _api(_body());

    final detail = await repo.adminDetail(42);

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
    expect(adapter.requests.single.path, '/api/admin/anuncios/42');
    expect(adapter.requests.single.path, isNot('/api/anuncios/42'));
    expect(detail.id, 42);
    expect(detail.status, AnnouncementStatus.expired);
    expect(detail.text, '**Comienza** el lunes');
    expect(detail.summary, isNull);
    expect(detail.images.single.url, 'https://almacen.example/101');
  });

  test('404 NO_ENCONTRADO se convierte en AnnouncementNotFoundException', () {
    final (repo, _) = _api({
      'code': 'NO_ENCONTRADO',
      'message': 'Anuncio no encontrado',
    }, status: 404);

    expect(repo.adminDetail(42), throwsA(isA<AnnouncementNotFoundException>()));
  });

  test('un id no positivo no llama a la API', () async {
    final (repo, adapter) = _api(_body());

    await expectLater(
      repo.adminDetail(0),
      throwsA(isA<AnnouncementNotFoundException>()),
    );
    expect(adapter.requests, isEmpty);
  });

  test('otro id en la respuesta o un cuerpo inválido dan el error genérico', () {
    final (mismatch, _) = _api(_body(id: 7));
    expect(mismatch.adminDetail(42), throwsA(isA<ApiException>()));

    final (invalid, _) = _api({'id': 42, 'estado': 'X'});
    expect(invalid.adminDetail(42), throwsA(isA<ApiException>()));
  });

  test('un 500 se informa como ApiException', () {
    final (repo, _) = _api({
      'code': 'ERROR',
      'message': 'Falla',
    }, status: 500);
    expect(repo.adminDetail(42), throwsA(isA<ApiException>()));
  });
}
