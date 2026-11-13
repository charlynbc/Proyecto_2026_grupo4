import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/repositories/api_user_status_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_status_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador de dio que anota el pedido y responde con lo indicado.
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

(ApiUserStatusRepository, _StubAdapter) _repository(int status, Object? body) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiUserStatusRepository(dio), adapter);
}

const _okBody = {
  'id': 42,
  'ci': '45678911',
  'nombre': 'Lucía',
  'apellido': 'Fernández',
  'rol': 'MEDICO',
  'estado': 'INACTIVA',
  'ultimaInactivacionEn': '2026-11-04T12:00:00-03:00',
  'ultimaInactivacionPor': 1,
  'ultimaReactivacionEn': null,
  'ultimaReactivacionPor': null,
};

Matcher _failure(UserStatusFailure failure, String message) =>
    isA<UserStatusException>()
        .having((e) => e.failure, 'failure', failure)
        .having((e) => e.message, 'message', message);

void main() {
  test(
    'inactivar hace POST a /inactivar sin cuerpo y lee la respuesta',
    () async {
      final (repository, adapter) = _repository(200, _okBody);

      final change = await repository.deactivate(42);

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/usuarios/42/inactivar');
      expect(adapter.last!.data, isNull);
      expect(change.id, 42);
      expect(change.role, UserRole.medico);
      expect(change.status, AccountStatus.inactive);
      expect(change.lastDeactivatedBy, 1);
    },
  );

  test('reactivar hace POST a /reactivar sin cuerpo', () async {
    final (repository, adapter) = _repository(200, {
      ..._okBody,
      'estado': 'ACTIVA',
    });

    final change = await repository.reactivate(42);

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/usuarios/42/reactivar');
    expect(adapter.last!.data, isNull);
    expect(change.status, AccountStatus.active);
  });

  final errors = <(int, String, UserStatusFailure)>[
    (404, 'USUARIO_NO_ENCONTRADO', UserStatusFailure.notFound),
    (409, 'CUENTA_YA_INACTIVA', UserStatusFailure.alreadyInactive),
    (409, 'CUENTA_YA_ACTIVA', UserStatusFailure.alreadyActive),
    (409, 'MEDICO_CON_TURNOS_ACTIVOS', UserStatusFailure.doctorHasShifts),
    (
      409,
      'MEDICO_CON_CONSULTAS_AGENDADAS',
      UserStatusFailure.doctorHasAppointments,
    ),
    (409, 'EMPLEADO_DUPLICADO', UserStatusFailure.duplicateStaff),
    (400, 'VALIDACION', UserStatusFailure.validation),
    (409, 'AUTO_INACTIVACION_NO_PERMITIDA', UserStatusFailure.ownAccount),
    (500, 'ERROR_INTERNO', UserStatusFailure.other),
  ];
  for (final (status, code, failure) in errors) {
    test(
      'inactivar: $status $code da $failure con el mensaje del servidor',
      () async {
        final (repository, _) = _repository(status, {
          'code': code,
          'message': 'Texto del servidor.',
        });

        await expectLater(
          repository.deactivate(42),
          throwsA(_failure(failure, 'Texto del servidor.')),
        );
      },
    );

    test(
      'reactivar: $status $code da $failure con el mensaje del servidor',
      () async {
        final (repository, _) = _repository(status, {
          'code': code,
          'message': 'Texto del servidor.',
        });

        await expectLater(
          repository.reactivate(42),
          throwsA(_failure(failure, 'Texto del servidor.')),
        );
      },
    );
  }

  test('una respuesta mal formada es el error genérico', () async {
    final (repository, _) = _repository(200, {'id': 42});

    await expectLater(
      repository.deactivate(42),
      throwsA(_failure(UserStatusFailure.other, kApiGenericMessage)),
    );
  });

  for (final id in [0, -3]) {
    test('el id $id es no encontrada y no hace ninguna llamada', () async {
      final (repository, adapter) = _repository(200, _okBody);

      await expectLater(
        repository.deactivate(id),
        throwsA(
          _failure(UserStatusFailure.notFound, 'No se encontró la cuenta.'),
        ),
      );
      await expectLater(
        repository.reactivate(id),
        throwsA(
          _failure(UserStatusFailure.notFound, 'No se encontró la cuenta.'),
        ),
      );
      expect(adapter.last, isNull);
    });
  }
}
