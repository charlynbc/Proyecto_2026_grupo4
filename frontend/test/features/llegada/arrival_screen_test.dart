import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/widgets/logout_button.dart';
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
import '../../helpers/load_roboto.dart';

class _RecordingAuthRepository implements AuthRepository {
  int logoutCalls = 0;

  @override
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  }) async {
    throw StateError('Estos tests no deben iniciar sesión.');
  }

  @override
  Future<void> refresh() async {
    throw const AuthException();
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }
}

Future<void> _settleLogout(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

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
  final Set<String> _registeredCis = {};
  int searchCalls = 0;
  int registerCalls = 0;
  Completer<void>? pending;

  /// Como el servidor: una vez registrada la llegada, la búsqueda la informa.
  @override
  Future<TodayAppointments> listTodayAppointments(String ci) async {
    searchCalls++;
    final result = await _fake.listTodayAppointments(ci);
    if (!_registeredCis.contains(normalizeCi(ci))) return result;
    return TodayAppointments(
      appointments: result.appointments,
      arrival: TodayArrival.fromArrival(_arrival),
    );
  }

  @override
  Future<ArrivalResult> registerArrival(String ci) async {
    registerCalls++;
    if (pending != null) await pending!.future;
    _registeredCis.add(normalizeCi(ci));
    return ArrivalResult(arrival: _arrival, created: created);
  }
}

/// Servidor falso: el GET devuelve la consulta de Ana, o 404 con [getError]
/// si está puesto, y el POST responde con [postStatus] y [postBody].
class _ServerAdapter implements HttpClientAdapter {
  _ServerAdapter({
    this.getError,
    this.postStatus = 201,
    this.postBody,
    this.getExtra = const {},
    this.noItems = false,
  });

  /// Campos que se suman a la respuesta del GET, como `llegada`.
  final Map<String, Object?> getExtra;

  /// El GET responde sin consultas agendadas.
  final bool noItems;

  Object? _withExtra(Object? body, bool isPost) {
    if (isPost || getError != null || body is! Map<String, dynamic>) {
      return body;
    }
    return {...body, if (noItems) 'items': <Object>[], ...getExtra};
  }

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
      jsonEncode(_withExtra(body, isPost)),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pump(
  WidgetTester tester,
  ArrivalRepository repository, {
  AuthRepository? auth,
  Size size = const Size(900, 1800),
}) async {
  await pumpAdminScreens(
    tester,
    initialLocation: '/llegada',
    size: size,
    routes: [
      GoRoute(path: '/llegada', builder: (_, _) => const ArrivalScreen()),
    ],
    overrides: [
      arrivalRepositoryProvider.overrideWith((ref) async => repository),
      if (auth != null)
        authRepositoryProvider.overrideWith((ref) async => auth),
    ],
  );
}

Finder get _ciField =>
    find.widgetWithText(TextFormField, 'Cédula de identidad');
Finder get _search => find.widgetWithText(FilledButton, 'Buscar');
Finder get _register => find.widgetWithText(FilledButton, 'Registrar llegada');
Finder get _registered =>
    find.widgetWithText(FilledButton, 'Llegada registrada a las 08:47');

const _stampedArrival = {
  'registradaEn': '2026-10-22T08:47:00-03:00',
  'registradaPor': {'id': 46, 'nombre': 'Mariana', 'apellido': 'Ferreira'},
};

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

  testWidgets('cambiar la CI despues de buscar no deja registrar la anterior', (
    tester,
  ) async {
    await _pump(tester, _RecordingRepository());
    await _searchCi(tester, '90000046');

    await tester.enterText(_ciField, '90000052');
    await tester.pump();

    expect(find.textContaining('Alejandro Rivas'), findsNothing);
    expect(_register, findsNothing);
  });

  testWidgets('mover el cursor en el campo no borra el resultado', (
    tester,
  ) async {
    await _pump(tester, _RecordingRepository());
    await _searchCi(tester, '90000046');

    tester
        .widget<EditableText>(find.byType(EditableText))
        .controller
        .selection = const TextSelection.collapsed(
      offset: 2,
    );
    await tester.pump();

    expect(find.textContaining('Alejandro Rivas'), findsOneWidget);
    expect(_enabled(tester, _register), isTrue);
  });

  testWidgets('201 muestra la llegada registrada con la hora', (tester) async {
    await _pump(tester, _RecordingRepository());
    await _searchCi(tester, '90000046');

    await tester.tap(_register);
    await tester.pumpAndSettle();

    expect(find.text('Llegada registrada a las 08:47.'), findsOneWidget);
  });

  testWidgets('201 deja el botón deshabilitado con la hora de la llegada', (
    tester,
  ) async {
    await _pump(tester, _RecordingRepository());
    await _searchCi(tester, '90000046');

    await tester.tap(_register);
    await tester.pumpAndSettle();

    expect(_registered, findsOneWidget);
    expect(_enabled(tester, _registered), isFalse);
    expect(_register, findsNothing);
    // En el 201 la registró quien está en la pantalla: no se nombra a nadie.
    expect(find.textContaining('La registró'), findsNothing);
  });

  testWidgets('200 deja el botón deshabilitado con la hora original y quien', (
    tester,
  ) async {
    await _pump(tester, _RecordingRepository(created: false));
    await _searchCi(tester, '90000046');

    await tester.tap(_register);
    await tester.pumpAndSettle();

    expect(_registered, findsOneWidget);
    expect(_enabled(tester, _registered), isFalse);
    expect(_register, findsNothing);
    expect(find.text('La registró Mariana Ferreira.'), findsOneWidget);
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
    // El aviso breve del 200 no es el del 201 (que termina en punto).
    expect(find.text('Llegada registrada a las 08:47.'), findsNothing);
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

  testWidgets('con el botón ya deshabilitado, tocarlo no pide nada más', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);
    await _searchCi(tester, '90000046');
    await tester.tap(_register);
    await tester.pumpAndSettle();
    expect(repository.registerCalls, 1);

    await tester.tap(_registered, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repository.registerCalls, 1);
    expect(_enabled(tester, _registered), isFalse);
  });

  testWidgets('cambiar la CI quita el estado registrado', (tester) async {
    await _pump(tester, _RecordingRepository());
    await _searchCi(tester, '90000046');
    await tester.tap(_register);
    await tester.pumpAndSettle();
    expect(_registered, findsOneWidget);

    await tester.enterText(_ciField, '90000052');
    await tester.pump();

    expect(_registered, findsNothing);
    expect(_register, findsNothing);

    // Al buscar a otro socio vuelve el botón normal, activo.
    await tester.tap(_search);
    await tester.pumpAndSettle();
    expect(_registered, findsNothing);
    expect(_enabled(tester, _register), isTrue);
  });

  testWidgets(
    'buscar de nuevo tras registrar muestra la llegada ya registrada',
    (tester) async {
      await _pump(tester, _RecordingRepository());
      await _searchCi(tester, '90000046');
      await tester.tap(_register);
      await tester.pumpAndSettle();
      expect(_registered, findsOneWidget);

      await tester.tap(_search);
      await tester.pumpAndSettle();

      expect(_registered, findsOneWidget);
      expect(_enabled(tester, _registered), isFalse);
      expect(_register, findsNothing);
      expect(find.text('La registró Mariana Ferreira.'), findsOneWidget);
    },
  );

  group('llegada ya registrada al buscar', () {
    testWidgets(
      'con llegada se ve la hora y quien, y el botón queda deshabilitado',
      (tester) async {
        final dio = Dio()
          ..httpClientAdapter = _ServerAdapter(
            getExtra: {'llegada': _stampedArrival},
          );
        await _pump(tester, ApiArrivalRepository(dio));

        await _searchCi(tester, '90000046');

        expect(find.textContaining('Alejandro Rivas'), findsOneWidget);
        expect(_registered, findsOneWidget);
        expect(_enabled(tester, _registered), isFalse);
        expect(_register, findsNothing);
        expect(find.text('La registró Mariana Ferreira.'), findsOneWidget);
      },
    );

    testWidgets('con llegada nula el botón sigue activo', (tester) async {
      final dio = Dio()
        ..httpClientAdapter = _ServerAdapter(getExtra: {'llegada': null});
      await _pump(tester, ApiArrivalRepository(dio));

      await _searchCi(tester, '90000046');

      expect(_enabled(tester, _register), isTrue);
      expect(_registered, findsNothing);
      expect(find.textContaining('La registró'), findsNothing);
    });

    testWidgets(
      'si el servidor no manda llegada, la pantalla funciona como antes',
      (tester) async {
        final dio = Dio()..httpClientAdapter = _ServerAdapter();
        await _pump(tester, ApiArrivalRepository(dio));

        await _searchCi(tester, '90000046');

        expect(_enabled(tester, _register), isTrue);
        expect(find.textContaining('La registró'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('el socio de los datos falsos con llegada la muestra', (
      tester,
    ) async {
      await _pump(tester, FakeArrivalRepository(latency: Duration.zero));

      await _searchCi(tester, '90000074');

      expect(_registered, findsOneWidget);
      expect(_enabled(tester, _registered), isFalse);
      expect(find.text('La registró Mariana Ferreira.'), findsOneWidget);
    });

    testWidgets('cambiar la CI vuelve al estado normal', (tester) async {
      await _pump(tester, FakeArrivalRepository(latency: Duration.zero));
      await _searchCi(tester, '90000074');
      expect(_registered, findsOneWidget);

      await tester.enterText(_ciField, '90000046');
      await tester.pump();

      expect(_registered, findsNothing);
      expect(find.textContaining('La registró'), findsNothing);

      await tester.tap(_search);
      await tester.pumpAndSettle();
      expect(_registered, findsNothing);
      expect(_enabled(tester, _register), isTrue);
    });

    testWidgets(
      'con llegada pero sin consultas agendadas muestra el aviso de sin consultas',
      (tester) async {
        final dio = Dio()
          ..httpClientAdapter = _ServerAdapter(
            noItems: true,
            getExtra: {'llegada': _stampedArrival},
          );
        await _pump(tester, ApiArrivalRepository(dio));

        await _searchCi(tester, '90000046');

        expect(
          find.text(
            'El socio no tiene consultas agendadas para hoy, así que no se '
            'puede registrar su llegada.',
          ),
          findsOneWidget,
        );
        expect(_enabled(tester, _register), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'si se busca a otro socio mientras se registra, no queda marcado',
    (tester) async {
      final repository = _RecordingRepository()..pending = Completer<void>();
      await _pump(tester, repository);
      await _searchCi(tester, '90000046');
      await tester.tap(_register);
      await tester.pump();

      // Antes de que termine el registro de Ana, se busca a Luis (90000052).
      await _searchCi(tester, '90000052');
      expect(find.textContaining('Beatriz Cabrera'), findsOneWidget);
      repository.pending!.complete();
      await tester.pumpAndSettle();

      // El aviso de Ana no se le pone al botón de Luis.
      expect(_registered, findsNothing);
      expect(find.text('La registró Mariana Ferreira.'), findsNothing);
      expect(_enabled(tester, _register), isTrue);
    },
  );

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

  group('RF-03', () {
    setUpAll(loadRoboto);

    testWidgets('muestra un único LogoutButton y tooltip Cerrar sesión', (
      tester,
    ) async {
      final auth = _RecordingAuthRepository();
      await _pump(tester, _RecordingRepository(), auth: auth);

      expect(find.byType(ArrivalScreen), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      expect(auth.logoutCalls, 0);
    });

    testWidgets('ubica LogoutButton en el AppBar y conserva el título', (
      tester,
    ) async {
      await _pump(
        tester,
        _RecordingRepository(),
        auth: _RecordingAuthRepository(),
      );

      expect(find.byType(ArrivalScreen), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);
      expect(
        find.descendant(of: appBar, matching: find.byType(LogoutButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: appBar, matching: find.text('Llegada')),
        findsOneWidget,
      );
    });

    testWidgets('Cancelar cierra el diálogo sin llamar a logout', (
      tester,
    ) async {
      final auth = _RecordingAuthRepository();
      await _pump(tester, _RecordingRepository(), auth: auth);

      expect(find.byType(ArrivalScreen), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
      final logout = find.byTooltip('Cerrar sesión');
      expect(logout, findsOneWidget);
      expect(auth.logoutCalls, 0);
      await tester.tap(logout);
      await _settleLogout(tester);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('¿Confirmás que querés cerrar la sesión?'),
        ),
        findsOneWidget,
      );
      final cancel = find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Cancelar'),
      );
      final confirm = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Cerrar sesión'),
      );
      expect(cancel, findsOneWidget);
      expect(confirm, findsOneWidget);
      expect(auth.logoutCalls, 0);

      await tester.tap(cancel);
      await _settleLogout(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ArrivalScreen), findsOneWidget);
      expect(auth.logoutCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Confirmar llama a logout exactamente una vez', (tester) async {
      final auth = _RecordingAuthRepository();
      await _pump(tester, _RecordingRepository(), auth: auth);

      expect(find.byType(ArrivalScreen), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
      final logout = find.byTooltip('Cerrar sesión');
      expect(logout, findsOneWidget);
      await tester.tap(logout);
      await _settleLogout(tester);

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      final confirm = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Cerrar sesión'),
      );
      expect(confirm, findsOneWidget);
      expect(auth.logoutCalls, 0);
      await tester.tap(confirm);
      await _settleLogout(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(auth.logoutCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a 320 px con Roboto muestra título y ambos accesos sin desbordes',
      (tester) async {
        await _pump(
          tester,
          _RecordingRepository(),
          auth: _RecordingAuthRepository(),
          size: const Size(320, 800),
        );

        expect(find.byType(ArrivalScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.byType(LogoutButton), findsOneWidget);
        final logout = find.byTooltip('Cerrar sesión');
        final account = find.byTooltip('Mi cuenta');
        expect(logout, findsOneWidget);
        expect(account, findsOneWidget);
        expect(logout.hitTestable(), findsOneWidget);
        expect(account.hitTestable(), findsOneWidget);
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Llegada'),
        );
        expect(title, findsOneWidget);
        expect(title.hitTestable(), findsOneWidget);
        expect(tester.view.physicalSize, const Size(320, 800));
        expect(tester.view.devicePixelRatio, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('resultado de la búsqueda a 320 px con Roboto', () {
    setUpAll(loadRoboto);

    testWidgets('con la llegada ya registrada al buscar no desborda', (
      tester,
    ) async {
      final dio = Dio()
        ..httpClientAdapter = _ServerAdapter(
          getExtra: {'llegada': _stampedArrival},
        );
      await _pump(
        tester,
        ApiArrivalRepository(dio),
        size: const Size(320, 800),
      );

      await _searchCi(tester, '90000046');

      await tester.ensureVisible(_registered);
      expect(_registered, findsOneWidget);
      expect(_enabled(tester, _registered), isFalse);
      expect(find.text('La registró Mariana Ferreira.'), findsOneWidget);
      final rect = tester.getRect(_registered);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });

    for (final (created, name) in [(true, '201'), (false, '200')]) {
      testWidgets('con el botón deshabilitado tras el $name no desborda', (
        tester,
      ) async {
        await _pump(
          tester,
          _RecordingRepository(created: created),
          size: const Size(320, 800),
        );
        await _searchCi(tester, '90000046');
        expect(find.textContaining('Alejandro Rivas'), findsOneWidget);

        await tester.ensureVisible(_register);
        await tester.tap(_register);
        await tester.pumpAndSettle();

        expect(_registered, findsOneWidget);
        expect(_enabled(tester, _registered), isFalse);
        if (!created) {
          expect(find.text('La registró Mariana Ferreira.'), findsOneWidget);
        }
        final rect = tester.getRect(_registered);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
