import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/llegada/models/arrival.dart';
import 'package:agenda_medica/features/llegada/providers/arrival_providers.dart';
import 'package:agenda_medica/features/llegada/repositories/api_arrival_repository.dart';
import 'package:agenda_medica/features/llegada/repositories/arrival_repository.dart';
import 'package:agenda_medica/features/llegada/repositories/fake_arrival_repository.dart';
import 'package:agenda_medica/features/llegada/screens/arrival_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';

/// Aviso fijo para comprobar los textos: llegó a las 08:47 de Uruguay y lo
/// registró Mariana Ferreira.
final _arrival = Arrival(
  id: 7,
  memberCi: '90000046',
  memberFirstName: 'Ana',
  memberLastName: 'Fernández',
  registeredAt: DateTime.parse('2026-10-22T08:47:00-03:00'),
  registeredByFirstName: 'Mariana',
  registeredByLastName: 'Ferreira',
);

/// Repositorio que cuenta las llamadas. Las consultas salen del falso; el
/// registro devuelve el aviso fijo, y espera a [pending] si está puesto.
class _RecordingRepository implements ArrivalRepository {
  _RecordingRepository({this.created = true});

  final bool created;
  final FakeArrivalRepository _fake = FakeArrivalRepository(
    latency: Duration.zero,
  );
  int searchCalls = 0;
  int registerCalls = 0;
  Completer<void>? pending;

  @override
  Future<List<Appointment>> listTodayAppointments(String ci) {
    searchCalls++;
    return _fake.listTodayAppointments(ci);
  }

  @override
  Future<ArrivalResult> registerArrival(String ci) async {
    registerCalls++;
    if (pending != null) await pending!.future;
    return ArrivalResult(arrival: _arrival, created: created);
  }
}

/// Servidor falso: el GET devuelve la consulta de Ana, o 404 con [getError]
/// si está puesto, y el POST responde con [postStatus] y [postBody].
class _ServerAdapter implements HttpClientAdapter {
  _ServerAdapter({this.getError, this.postStatus = 201, this.postBody});

  final Object? getError;
  final int postStatus;
  final Object? postBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isPost = options.method == 'POST';
    final status = isPost ? postStatus : (getError == null ? 200 : 404);
    final body = isPost
        ? postBody
        : getError ??
              {
                'items': [
                  {
                    'id': 184,
                    'estado': 'AGENDADA',
                    'fecha': '2026-10-22',
                    'numero': 2,
                    'horaInicio': '09:00',
                    'horaFin': '09:20',
                    'medico': {
                      'id': 41,
                      'nombre': 'Alejandro',
                      'apellido': 'Rivas',
                    },
                    'especialidad': {
                      'id': 1,
                      'nombre': 'Medicina general',
                      'requierePase': false,
                    },
                    'consultorio': {
                      'id': 1,
                      'nombre': 'Consultorio 1',
                      'ubicacion': 'Planta baja, sector 1',
                    },
                    'paseId': null,
                    'agendadaEn': '2026-10-15T10:00:00-03:00',
                    'canceladaEn': null,
                    'motivoCancelacion': null,
                  },
                ],
              };
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

Future<void> _pump(WidgetTester tester, ArrivalRepository repository) async {
  await pumpAdminScreens(
    tester,
    initialLocation: '/llegada',
    routes: [
      GoRoute(path: '/llegada', builder: (_, _) => const ArrivalScreen()),
    ],
    overrides: [
      arrivalRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
}

Finder get _ciField =>
    find.widgetWithText(TextFormField, 'Cédula de identidad');
Finder get _search => find.widgetWithText(FilledButton, 'Buscar');
Finder get _register => find.widgetWithText(FilledButton, 'Registrar llegada');

Future<void> _searchCi(WidgetTester tester, String ci) async {
  await tester.enterText(_ciField, ci);
  await tester.tap(_search);
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<FilledButton>(button).onPressed != null;

void main() {
  testWidgets('una CI invalida muestra el error y no consulta', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);

    await _searchCi(tester, '1234567');

    expect(find.textContaining('La cédula no es válida'), findsOneWidget);
    expect(repository.searchCalls, 0);
  });

  testWidgets('Ana tiene una consulta hoy con medico, hora y consultorio', (
    tester,
  ) async {
    await _pump(tester, _RecordingRepository());

    await _searchCi(tester, '90000046');

    expect(find.textContaining('Alejandro Rivas'), findsOneWidget);
    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.textContaining('Consultorio 1'), findsOneWidget);
    expect(_enabled(tester, _register), isTrue);
  });

  testWidgets('404 al buscar muestra que no hay un socio con esa CI', (
    tester,
  ) async {
    final dio = Dio()
      ..httpClientAdapter = _ServerAdapter(
        getError: {'code': 'NO_ENCONTRADO', 'message': 'Texto del servidor'},
      );
    await _pump(tester, ApiArrivalRepository(dio));

    await _searchCi(tester, '12345672');

    expect(
      find.text(
        'No encontramos un socio activo con esa cédula. Revisá el número y '
        'probá de nuevo.',
      ),
      findsOneWidget,
    );
    expect(_register, findsNothing);
  });

  testWidgets('Laura no tiene consultas y no se puede registrar', (
    tester,
  ) async {
    await _pump(tester, _RecordingRepository());

    await _searchCi(tester, '90000068');

    expect(
      find.textContaining('no tiene consultas agendadas para hoy'),
      findsOneWidget,
    );
    expect(_enabled(tester, _register), isFalse);
  });

  testWidgets('201 muestra la llegada registrada con la hora', (tester) async {
    await _pump(tester, _RecordingRepository());
    await _searchCi(tester, '90000046');

    await tester.tap(_register);
    await tester.pumpAndSettle();

    expect(find.text('Llegada registrada a las 08:47.'), findsOneWidget);
  });

  testWidgets('200 muestra que ya estaba registrada, con hora y quien', (
    tester,
  ) async {
    await _pump(tester, _RecordingRepository(created: false));
    await _searchCi(tester, '90000046');

    await tester.tap(_register);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'La llegada ya estaba registrada a las 08:47. '
        'La registró Mariana Ferreira.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Llegada registrada'), findsNothing);
  });

  testWidgets('dos toques seguidos en Registrar hacen una sola llamada', (
    tester,
  ) async {
    final repository = _RecordingRepository()..pending = Completer<void>();
    await _pump(tester, repository);
    await _searchCi(tester, '90000046');

    await tester.tap(_register);
    await tester.pump();
    await tester.tap(_register, warnIfMissed: false);
    await tester.pump();
    repository.pending!.complete();
    await tester.pumpAndSettle();

    expect(repository.registerCalls, 1);
  });

  for (final code in ['CONFLICTO_INTERES', 'CONFLICTO_DE_INTERES']) {
    testWidgets('403 $code muestra el mensaje de conflicto de interes', (
      tester,
    ) async {
      final dio = Dio()
        ..httpClientAdapter = _ServerAdapter(
          postStatus: 403,
          postBody: {'code': code, 'message': 'Texto del servidor'},
        );
      await _pump(tester, ApiArrivalRepository(dio));
      await _searchCi(tester, '90000046');

      await tester.tap(_register);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No podés registrar tu propia llegada. Pedile a otro funcionario '
          'que la registre.',
        ),
        findsOneWidget,
      );
    });
  }

  for (final code in ['SIN_CONSULTAS_AGENDADAS', 'SIN_CONSULTAS_HOY']) {
    testWidgets('409 $code muestra el mensaje de sin consultas', (
      tester,
    ) async {
      final dio = Dio()
        ..httpClientAdapter = _ServerAdapter(
          postStatus: 409,
          postBody: {'code': code, 'message': 'Texto del servidor'},
        );
      await _pump(tester, ApiArrivalRepository(dio));
      await _searchCi(tester, '90000046');

      await tester.tap(_register);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'El socio no tiene consultas agendadas para hoy, así que no se '
          'puede registrar su llegada.',
        ),
        findsOneWidget,
      );
    });
  }
}
