import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/utils/ui_date.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/api_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/medical_history_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registra el pedido y responde en memoria, sin utilizar la red.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Object? body;
  final List<RequestOptions> requests = [];

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

(ApiMedicalHistoryRepository, _StubAdapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));

  return (ApiMedicalHistoryRepository(dio), adapter);
}

/// Usa el ejemplo de Trello; permite distinguir los elementos de una lista.
Map<String, dynamic> _entryJson(int id) => {
  'idAtencion': id,
  'fechaAtencion': '2026-09-24',
  'medicoId': 4,
  'medicoNombre': 'Diego',
  'medicoApellido': 'Viera',
  'especialidad': {
    'id': 3,
    'nombre': 'Cardiología',
    'requierePase': true,
  },
  'afeccion': 'gripe',
  'tratamiento': null,
  'observaciones': null,
  'pases': <dynamic>[],
};

void main() {
  group('ApiMedicalHistoryRepository.list', () {
    test('envía exactamente los filtros del ejemplo de Trello', () async {
      final (repository, adapter) = _repository(200, <Object>[]);

      await repository.list(
        MedicalHistoryQuery(
          from: DateTime.utc(2026, 9, 1),
          specialtyId: 3,
          text: 'reposo',
        ),
      );

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/historia-clinica');
      expect(request.queryParameters, {
        'fechaDesde': '2026-09-01',
        'especialidadId': 3,
        'texto': 'reposo',
        'orden': 'fecha_atencion',
        'sentido': 'desc',
      });
    });

    test('sin filtros envía solo el orden y sentido predeterminados', () async {
      final (repository, adapter) = _repository(200, <Object>[]);

      await repository.list(const MedicalHistoryQuery());

      expect(adapter.requests.single.queryParameters, {
        'orden': 'fecha_atencion',
        'sentido': 'desc',
      });
    });

    test('omite texto vacío en lugar de enviar texto vacío', () async {
      final (repository, adapter) = _repository(200, <Object>[]);

      await repository.list(const MedicalHistoryQuery(text: ''));

      expect(adapter.requests.single.queryParameters, {
        'orden': 'fecha_atencion',
        'sentido': 'desc',
      });
    });

    test('ordenar por especialidad envía orden=especialidad', () async {
      final (repository, adapter) = _repository(200, <Object>[]);

      await repository.list(
        const MedicalHistoryQuery(order: MedicalHistoryOrder.specialty),
      );

      expect(adapter.requests.single.queryParameters, {
        'orden': 'especialidad',
        'sentido': 'desc',
      });
    });

    test('ordenar por fecha envía fecha_atencion con guion bajo', () async {
      final (repository, adapter) = _repository(200, <Object>[]);

      await repository.list(
        const MedicalHistoryQuery(order: MedicalHistoryOrder.date),
      );

      expect(adapter.requests.single.queryParameters, {
        'orden': 'fecha_atencion',
        'sentido': 'desc',
      });
    });

    test('interpreta un arreglo de tres elementos como tres atenciones', () async {
      final (repository, _) = _repository(200, [
        _entryJson(10),
        _entryJson(11),
        _entryJson(12),
      ]);

      final entries = await repository.list(const MedicalHistoryQuery());

      expect(entries, hasLength(3));
      expect(entries.map((entry) => entry.id), [10, 11, 12]);
      expect(entries.first.doctorFullName, 'Diego Viera');
      expect(entries.first.specialty.name, 'Cardiología');
    });

    test('interpreta un arreglo vacío como cero atenciones', () async {
      final (repository, _) = _repository(200, <Object>[]);

      final entries = await repository.list(const MedicalHistoryQuery());

      expect(entries, isEmpty);
    });
  });

  group('ApiMedicalHistoryRepository.get', () {
    test('interpreta una respuesta 200 con la atención de Trello', () async {
      final (repository, adapter) = _repository(200, _entryJson(10));

      final entry = await repository.get(10);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/historia-clinica/10');
      expect(request.queryParameters, isEmpty);

      expect(entry.id, 10);
      expect(formatUiDate(entry.attendedOn), '24/09/2026');
      expect(entry.doctorId, 4);
      expect(entry.doctorFirstName, 'Diego');
      expect(entry.doctorLastName, 'Viera');
      expect(entry.doctorFullName, 'Diego Viera');
      expect(entry.specialty.id, 3);
      expect(entry.specialty.name, 'Cardiología');
      expect(entry.specialty.requiresReferral, isTrue);
      expect(entry.condition, 'gripe');
      expect(entry.treatment, isNull);
      expect(entry.observations, isNull);
      expect(entry.referrals, hasLength(0));
    });

    test(
      'HISTORIA_NO_ENCONTRADA se convierte en un error tipado '
      'con mensaje comprensible',
      () async {
        final (repository, adapter) = _repository(404, {
          'code': 'HISTORIA_NO_ENCONTRADA',
          'message': 'La atención no existe o no pertenece a este socio.',
        });

        await expectLater(
          repository.get(10),
          throwsA(
            isA<MedicalHistoryNotFoundException>()
                .having(
                  (error) => error.message.trim(),
                  'mensaje no vacío',
                  isNotEmpty,
                )
                .having(
                  (error) => error.message,
                  'no expone el código',
                  isNot(contains('HISTORIA_NO_ENCONTRADA')),
                ),
          ),
        );

        final request = adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.path, '/api/historia-clinica/10');
        expect(request.queryParameters, isEmpty);
      },
    );
  });
}
