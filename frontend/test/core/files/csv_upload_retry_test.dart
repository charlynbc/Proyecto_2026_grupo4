import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:agenda_medica/core/network/auth_interceptor.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Handler = FutureOr<ResponseBody> Function(RequestOptions options);

/// Adaptador falso que, además de anotar la ruta, lee el cuerpo que llegaría
/// al servidor.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final _Handler handler;
  final List<String> paths = [];
  final List<String> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    final chunks = requestStream == null
        ? <Uint8List>[]
        : await requestStream.toList();
    bodies.add(utf8.decode(chunks.expand((c) => c).toList()));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Un repository que nunca termina: evita que el bootstrap de la sesión pise
/// el estado que arma cada test.
class _IdleAuthRepository implements AuthRepository {
  @override
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  }) => Completer<void>().future;

  @override
  Future<void> refresh() => Completer<void>().future;

  @override
  Future<void> logout() => Completer<void>().future;
}

const _upload = ApiRoutes.specialtiesImportPreview;
const _csv = 'nombre,requiere_pase\nCardiologia,si\n';

void main() {
  late _FakeAdapter adapter;
  late Dio dio;

  /// Responde 401 al primer POST de la carga, 200 al refresh y 200 al
  /// segundo POST.
  void setUpWith() {
    var uploads = 0;
    adapter = _FakeAdapter((o) {
      if (o.path == ApiRoutes.authRefresh) {
        return _json(200, {'token': 'nuevo', 'role': 'ADMINISTRADOR'});
      }
      uploads++;
      return uploads == 1
          ? _json(401, {'code': 'NO_AUTENTICADO'})
          : _json(200, {'ok': true});
    });
    final dioProvider = Provider<Dio>((ref) {
      final dio = Dio(BaseOptions(baseUrl: 'http://prueba'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(AuthInterceptor(dio, ref));
      return dio;
    });
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) async => _IdleAuthRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    dio = container.read(dioProvider);
    container
        .read(sessionProvider.notifier)
        .setAuthenticated(accessToken: 'viejo', role: UserRole.administrador);
  }

  test(
    'un multipart que recibe 401 se reintenta con el mismo archivo',
    () async {
      setUpWith();
      // Armado a mano, sin las funciones de la tarjeta: este test solo mira el
      // interceptor.
      final formData = FormData.fromMap({
        'archivo': MultipartFile.fromBytes(
          utf8.encode(_csv),
          filename: 'especialidades.csv',
          contentType: DioMediaType('text', 'csv'),
        ),
      });

      final response = await dio.post<dynamic>(_upload, data: formData);

      expect(response.statusCode, 200);
      expect(adapter.paths, [_upload, ApiRoutes.authRefresh, _upload]);
      expect(adapter.bodies.first, contains(_csv));
      expect(adapter.bodies.last, contains(_csv));
      expect(adapter.bodies.last, contains('filename="especialidades.csv"'));
    },
  );

  test(
    'un POST con JSON que recibe 401 se reintenta igual que antes',
    () async {
      setUpWith();

      final response = await dio.post<dynamic>(_upload, data: {'a': 1});

      expect(response.statusCode, 200);
      expect(adapter.paths, [_upload, ApiRoutes.authRefresh, _upload]);
      expect(jsonDecode(adapter.bodies.last), {'a': 1});
    },
  );
}
