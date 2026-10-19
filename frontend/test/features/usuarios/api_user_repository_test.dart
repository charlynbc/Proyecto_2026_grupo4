import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/new_user.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/models/user_filters.dart';
import 'package:agenda_medica/features/usuarios/repositories/api_user_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_repository.dart';
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

(ApiUserRepository, _StubAdapter) _repository(int status, Object? body) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiUserRepository(dio), adapter);
}

NewUser _newUser({UserRole role = UserRole.medico}) => NewUser(
  ci: '19119219',
  firstName: 'Marta',
  lastName: 'Rodríguez',
  birthDate: DateTime(1978, 3, 15),
  email: 'marta@example.org',
  phone1: '099111222',
  role: role,
  specialtyIds: role == UserRole.medico ? [1, 3] : [],
);

void main() {
  test('el listado envía los filtros del contrato y lee la página', () async {
    final (repository, adapter) = _repository(200, {
      'items': [
        {
          'id': 42,
          'ci': '45678911',
          'nombre': 'Lucía',
          'apellido': 'Fernández',
          'rol': 'SOCIO',
          'correo': 'lucia@example.org',
          'estado': 'ACTIVA',
          'activada': true,
          'fechaAlta': '2026-09-01T09:00:00-03:00',
        },
      ],
      'page': 1,
      'size': 20,
      'total': 21,
    });

    final page = await repository.listUsers(
      const UserFilters(
        role: UserRole.socio,
        status: AccountStatus.active,
        query: ' fernandez ',
        order: UserOrder.createdAt,
        ascending: false,
        page: 1,
      ),
    );

    expect(adapter.last!.path, '/api/usuarios');
    expect(adapter.last!.queryParameters, {
      'rol': 'SOCIO',
      'estado': 'ACTIVA',
      'q': 'fernandez',
      'orden': 'fechaAlta',
      'sentido': 'desc',
      'page': 1,
      'size': 20,
    });
    expect(page.total, 21);
    expect(page.hasPrevious, isTrue);
    expect(page.items.single.lastName, 'Fernández');
    expect(page.items.single.role, UserRole.socio);
  });

  test('un filtro vacío no se envía', () async {
    final (repository, adapter) = _repository(200, {
      'items': <Object>[],
      'page': 0,
      'size': 20,
      'total': 0,
    });

    await repository.listUsers(const UserFilters());

    expect(adapter.last!.queryParameters.keys, [
      'orden',
      'sentido',
      'page',
      'size',
    ]);
  });

  test('el alta envía los campos del contrato', () async {
    final (repository, adapter) = _repository(201, {'id': 17});

    await repository.createUser(_newUser());

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.data, {
      'ci': '19119219',
      'nombre': 'Marta',
      'apellido': 'Rodríguez',
      'fechaNacimiento': '1978-03-15',
      'correo': 'marta@example.org',
      'telefono1': '099111222',
      'telefono2': null,
      'direccion': null,
      'rol': 'MEDICO',
      'especialidadIds': [1, 3],
    });
  });

  test('un rol distinto de Médico no envía especialidadIds', () async {
    final (repository, adapter) = _repository(201, {'id': 17});

    await repository.createUser(_newUser(role: UserRole.funcionario));

    expect((adapter.last!.data as Map).containsKey('especialidadIds'), isFalse);
  });

  group('errores por code', () {
    Future<Object> failWith(int status, String code) async {
      final (repository, _) = _repository(status, {
        'code': code,
        'message': 'Mensaje del servidor.',
      });
      try {
        await repository.createUser(_newUser());
      } catch (e) {
        return e;
      }
      throw StateError('Tenía que fallar');
    }

    test('CI_INVALIDA', () async {
      expect(await failWith(400, 'CI_INVALIDA'), isA<InvalidCiException>());
    });

    test('DATOS_PERSONA_DISCORDANTES', () async {
      expect(
        await failWith(409, 'DATOS_PERSONA_DISCORDANTES'),
        isA<MismatchedPersonDataException>(),
      );
    });

    test('SOCIO_DUPLICADO', () async {
      expect(
        await failWith(409, 'SOCIO_DUPLICADO'),
        isA<DuplicateMemberException>(),
      );
    });

    test('EMPLEADO_DUPLICADO muestra el mensaje del servidor', () async {
      final error = await failWith(409, 'EMPLEADO_DUPLICADO');
      expect(error, isA<DuplicateStaffException>());
      expect(
        (error as DuplicateStaffException).message,
        'Mensaje del servidor.',
      );
    });
  });
}
