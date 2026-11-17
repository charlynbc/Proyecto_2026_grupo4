import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/repositories/api_announcements_repository.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _endMessage =
    'La fecha de fin es obligatoria y debe ser posterior al inicio';

// "Ahora" fijo: 14/11/2026 12:00 en Uruguay (15:00 UTC).
final _now = DateTime.utc(2026, 11, 14, 15);

AnnouncementDraft _draft({DateTime? from, DateTime? until}) =>
    AnnouncementDraft(
      title: 'Campaña',
      text: 'Texto',
      visibleFrom: from,
      visibleUntil: until,
    );

class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 201, this.body = const {}});
  final int status;
  final Object? body;
  String? multipart;
  RequestOptions? request;

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

(ApiAnnouncementsRepository, _Adapter) _api({
  int status = 201,
  Object? body = const {},
}) {
  final adapter = _Adapter(status: status, body: body);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (ApiAnnouncementsRepository(dio), adapter);
}

Map<String, dynamic> _sentData(_Adapter adapter) {
  final boundary = (adapter.request!.data as FormData).boundary;
  final part = adapter.multipart!
      .split('--$boundary')
      .singleWhere((p) => p.contains('name="datos"'));
  return jsonDecode(part.split('\r\n\r\n').last) as Map<String, dynamic>;
}

void main() {
  group('validación de la visibilidad, con los mensajes del backend', () {
    test('sin fecha de fin no se puede publicar', () {
      expect(_draft().validateVisibility(_now), _endMessage);
    });

    test('sin fecha de fin tampoco, aunque haya inicio', () {
      expect(
        _draft(from: DateTime.utc(2026, 12, 1, 3)).validateVisibility(_now),
        _endMessage,
      );
    });

    test('un fin igual al inicio no es posterior', () {
      final same = DateTime.utc(2026, 12, 1, 3);
      expect(
        _draft(from: same, until: same).validateVisibility(_now),
        _endMessage,
      );
    });

    test('un fin anterior al inicio no es válido', () {
      expect(
        _draft(
          from: DateTime.utc(2026, 12, 1, 3),
          until: DateTime.utc(2026, 11, 30, 3),
        ).validateVisibility(_now),
        _endMessage,
      );
    });

    test('sin inicio, un fin que ya pasó no es válido', () {
      expect(
        _draft(until: DateTime.utc(2026, 11, 14, 14, 59))
            .validateVisibility(_now),
        _endMessage,
      );
    });

    test('sin inicio, un fin igual a ahora no es posterior', () {
      expect(_draft(until: _now).validateVisibility(_now), _endMessage);
    });

    test('sin inicio, un fin un minuto después de ahora es válido', () {
      expect(
        _draft(until: DateTime.utc(2026, 11, 14, 15, 1))
            .validateVisibility(_now),
        isNull,
      );
    });

    test('con inicio y fin posterior al inicio es válido', () {
      expect(
        _draft(
          from: DateTime.utc(2026, 12, 1, 3),
          until: DateTime.utc(2027, 1, 1, 2, 59),
        ).validateVisibility(_now),
        isNull,
      );
    });

    test('con inicio, el fin se compara con el inicio y no con ahora', () {
      // Igual que el backend: inicio y fin pasados pero en orden es válido.
      expect(
        _draft(
          from: DateTime.utc(2026, 1, 1, 3),
          until: DateTime.utc(2026, 1, 2, 3),
        ).validateVisibility(_now),
        isNull,
      );
    });
  });

  group('el repositorio Api manda las fechas con desfase -03:00', () {
    test('con inicio y fin manda vigenteDesde y vigenteHasta', () async {
      final (repo, adapter) = _api();

      await repo.publish(
        _draft(
          from: DateTime.utc(2026, 12, 1, 3),
          until: DateTime.utc(2027, 1, 1, 2, 59),
        ),
      );

      expect(_sentData(adapter), {
        'titulo': 'Campaña',
        'texto': 'Texto',
        'vigenteDesde': '2026-12-01T00:00:00-03:00',
        'vigenteHasta': '2026-12-31T23:59:00-03:00',
      });
    });

    test('sin inicio manda solo vigenteHasta', () async {
      final (repo, adapter) = _api();

      await repo.publish(_draft(until: DateTime.utc(2027, 1, 1, 3)));

      final data = _sentData(adapter);
      expect(data['vigenteHasta'], '2027-01-01T00:00:00-03:00');
      expect(data.containsKey('vigenteDesde'), isFalse);
    });

    test('un instante con otro offset se manda expresado en Uruguay', () async {
      final (repo, adapter) = _api();

      await repo.publish(
        _draft(until: DateTime.parse('2027-01-01T05:00:00+02:00')),
      );

      expect(_sentData(adapter)['vigenteHasta'], '2027-01-01T00:00:00-03:00');
    });

    test('ninguna fecha enviada termina en Z ni sin desfase', () async {
      final (repo, adapter) = _api();

      await repo.publish(
        _draft(
          from: DateTime.utc(2026, 12, 1, 12),
          until: DateTime.utc(2027, 1, 1, 12),
        ),
      );

      final data = _sentData(adapter);
      for (final key in ['vigenteDesde', 'vigenteHasta']) {
        expect(data[key], endsWith('-03:00'), reason: key);
        expect(data[key], isNot(contains('Z')), reason: key);
      }
    });

    test('un 400 del servidor muestra su mensaje', () async {
      final (repo, _) = _api(
        status: 400,
        body: {'code': 'VALIDACION', 'message': _endMessage},
      );

      await expectLater(
        repo.publish(_draft(until: DateTime.utc(2027, 1, 1, 3))),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', _endMessage),
        ),
      );
    });
  });

  group('el Fake aplica la misma validación y responde el mismo 400', () {
    FakeAnnouncementsRepository fake() =>
        FakeAnnouncementsRepository(now: () => _now);

    Matcher endError() => throwsA(
      isA<ApiException>().having((e) => e.message, 'message', _endMessage),
    );

    test('sin fin', () async {
      await expectLater(fake().publish(_draft()), endError());
    });

    test('fin igual al inicio', () async {
      final same = DateTime.utc(2026, 12, 1, 3);
      await expectLater(
        fake().publish(_draft(from: same, until: same)),
        endError(),
      );
    });

    test('fin anterior al inicio', () async {
      await expectLater(
        fake().publish(
          _draft(
            from: DateTime.utc(2026, 12, 1, 3),
            until: DateTime.utc(2026, 11, 30, 3),
          ),
        ),
        endError(),
      );
    });

    test('sin inicio y con fin pasado', () async {
      await expectLater(
        fake().publish(_draft(until: DateTime.utc(2026, 11, 14, 14, 59))),
        endError(),
      );
    });

    test('con fin válido publica y la novedad aparece en la lista', () async {
      final repository = fake();

      await repository.publish(_draft(until: DateTime.utc(2027, 1, 1, 3)));

      final page = await repository.list();
      expect(page.items.first.title, 'Campaña');
    });

    test('una publicación rechazada no queda en la lista', () async {
      final repository = fake();

      await expectLater(repository.publish(_draft()), endError());

      final page = await repository.list();
      expect(page.items.map((i) => i.title), isNot(contains('Campaña')));
    });
  });
}
