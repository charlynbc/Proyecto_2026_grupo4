import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/agenda/screens/appointments_pending_screen.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart' show goTo, unmountApp;

/// Mis consultas y el detalle tienen que mostrar siempre el estado actual de
/// la consulta, aunque lo haya cambiado otra persona (el funcionario, el
/// médico) mientras el socio estaba en otra pantalla. La semilla de Ana tiene
/// tres consultas: la 1 Agendada (dentro de 12 días), la 2 Cancelada por el
/// socio y la 3 Atendida.

const _loadFailure = 'No pudimos cargar tus consultas de prueba.';

/// El repositorio falso de siempre, que además cuenta los pedidos del listado
/// (de a 20; los de a 100 son los de las opciones de los filtros) y los del
/// detalle, y puede fallar al listar.
class _ControlledRepository extends FakeAppointmentHistoryRepository {
  _ControlledRepository(super.db);

  bool failList = false;
  int listCalls = 0;
  int detailCalls = 0;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) {
    if (query.size == 20) {
      listCalls++;
      if (failList) return Future.error(const ApiException(_loadFailure));
    }
    return super.list(query);
  }

  @override
  Future<Appointment> get(int id) {
    detailCalls++;
    return super.get(id);
  }
}

/// La app completa con el router real, la sesión real y el historial de
/// [_ControlledRepository]. El socio entra como Ana Rodríguez.
Future<(ProviderContainer, _ControlledRepository)> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  late _ControlledRepository history;
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      authRepositoryProvider.overrideWith(
        (ref) async => FakeAuthRepository(
          ref.read(sessionProvider.notifier),
          latency: Duration.zero,
        ),
      ),
      appointmentHistoryRepositoryProvider.overrideWith((ref) async {
        history = _ControlledRepository(ref.watch(fakeDatabaseProvider));
        return history;
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(goRouterProvider)),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final person = TestData.people.firstWhere((p) => p.role == kRoleMember);
  final auth = await container.read(authRepositoryProvider.future);
  final done = auth.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.socio,
  );
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
  // El repositorio se crea al pedir la primera consulta.
  await container.read(appointmentHistoryRepositoryProvider.future);
  return (container, history);
}

/// Deja pasar la latencia de los repositories falsos (300 ms). Son dos pasos
/// porque un pedido que arranca después de la transición de una pantalla
/// (por ejemplo, al volver del detalle) agenda su espera recién en el primero.
Future<void> _wait(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _openMyAppointments(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await goTo(tester, container, '/socio/consultas');
  await _wait(tester);
  expect(find.byType(AppointmentsPendingScreen), findsOneWidget);
}

/// Lo que hace el funcionario o el médico del otro lado: la consulta [id] pasa
/// a [status] sin que el socio haga nada.
void _changeStatus(ProviderContainer container, int id, String status) {
  final db = container.read(fakeDatabaseProvider);
  final index = db.appointments.indexWhere((a) => a.id == id);
  final a = db.appointments[index];
  db.appointments[index] = Appointment(
    id: a.id,
    status: status,
    date: a.date,
    number: a.number,
    startMinutes: a.startMinutes,
    endMinutes: a.endMinutes,
    doctor: a.doctor,
    specialty: a.specialty,
    clinic: a.clinic,
    referralId: a.referralId,
    bookedAt: a.bookedAt,
    cancelledAt: status.startsWith('CANCELADA')
        ? DateTime.utc(2026, 11, 15, 19)
        : null,
    cancellationReason: null,
  );
}

Finder _title(String text, {int id = 1}) => find.descendant(
  of: find.byKey(Key('appointment-$id')),
  matching: find.text(text),
);

Future<void> _toggleDirection(WidgetTester tester) async {
  final button = find.byKey(const Key('history-filter-direction'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await _wait(tester);
}

Future<void> _pickStatus(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('history-filter-status')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await _wait(tester);
}

void main() {
  testWidgets('la lista vuelve a pedir las consultas al volver a la sección '
      '(orden Descendente)', (tester) async {
    final (container, _) = await _pump(tester);
    await _openMyAppointments(tester, container);
    expect(_title('Dermatología · Agendada'), findsOneWidget);

    await goTo(tester, container, '/socio/disponibilidad');
    _changeStatus(container, 1, 'CANCELADA_SOCIO');
    await _openMyAppointments(tester, container);

    expect(_title('Dermatología · Cancelada por el socio'), findsOneWidget);
    expect(_title('Dermatología · Agendada'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('con orden Ascendente se ve el mismo estado actual que con '
      'Descendente', (tester) async {
    final (container, _) = await _pump(tester);
    await _openMyAppointments(tester, container);
    _changeStatus(container, 1, 'CANCELADA_SOCIO');
    await goTo(tester, container, '/socio/disponibilidad');
    await _openMyAppointments(tester, container);

    expect(_title('Dermatología · Cancelada por el socio'), findsOneWidget);
    await _toggleDirection(tester);
    expect(_title('Dermatología · Cancelada por el socio'), findsOneWidget);
    await _toggleDirection(tester);
    expect(_title('Dermatología · Cancelada por el socio'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('el detalle muestra el estado actual al abrirlo de nuevo', (
    tester,
  ) async {
    final (container, _) = await _pump(tester);
    await _openMyAppointments(tester, container);
    await tester.tap(find.byKey(const Key('appointment-1')));
    await _wait(tester);
    expect(find.byType(AppointmentDetailScreen), findsOneWidget);
    expect(find.text('Agendada'), findsOneWidget);

    await tester.pageBack();
    await _wait(tester);
    _changeStatus(container, 1, 'CANCELADA_SOCIO');
    await tester.tap(find.byKey(const Key('appointment-1')));
    await _wait(tester);

    expect(find.byType(AppointmentDetailScreen), findsOneWidget);
    expect(find.text('Cancelada por el socio'), findsOneWidget);
    expect(find.text('Agendada'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('el detalle abierto se actualiza al volver a la sección', (
    tester,
  ) async {
    final (container, _) = await _pump(tester);
    await _openMyAppointments(tester, container);
    await tester.tap(find.byKey(const Key('appointment-1')));
    await _wait(tester);
    expect(find.text('Agendada'), findsOneWidget);

    await goTo(tester, container, '/socio/disponibilidad');
    _changeStatus(container, 1, 'ATENDIDA');
    await goTo(tester, container, '/socio/consultas/1');
    await _wait(tester);

    expect(find.byType(AppointmentDetailScreen), findsOneWidget);
    expect(find.text('Atendida'), findsOneWidget);
    expect(find.text('Agendada'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('al volver del detalle a la lista, la lista se actualiza', (
    tester,
  ) async {
    final (container, _) = await _pump(tester);
    await _openMyAppointments(tester, container);
    await tester.tap(find.byKey(const Key('appointment-1')));
    await _wait(tester);

    _changeStatus(container, 1, 'ATENDIDA');
    await tester.pageBack();
    await _wait(tester);

    expect(find.byType(AppointmentsPendingScreen), findsOneWidget);
    expect(_title('Dermatología · Atendida'), findsOneWidget);
    await unmountApp(tester);
  });

  group('al entrar', () {
    testWidgets('se pide el listado una sola vez por entrada', (tester) async {
      final (container, repo) = await _pump(tester);

      await _openMyAppointments(tester, container);
      expect(repo.listCalls, 1);

      await goTo(tester, container, '/socio/disponibilidad');
      await _wait(tester);
      expect(repo.listCalls, 1);

      await _openMyAppointments(tester, container);
      expect(repo.listCalls, 2);
      await unmountApp(tester);
    });

    testWidgets('se pide el detalle una sola vez por apertura', (tester) async {
      final (container, repo) = await _pump(tester);
      await _openMyAppointments(tester, container);

      await tester.tap(find.byKey(const Key('appointment-1')));
      await _wait(tester);
      expect(repo.detailCalls, 1);

      await tester.pageBack();
      await _wait(tester);
      await tester.tap(find.byKey(const Key('appointment-1')));
      await _wait(tester);
      expect(repo.detailCalls, 2);
      await unmountApp(tester);
    });

    testWidgets(
      'el detalle reabierto no muestra el estado viejo mientras llega '
      'el nuevo',
      (tester) async {
        final (container, _) = await _pump(tester);
        await _openMyAppointments(tester, container);
        await tester.tap(find.byKey(const Key('appointment-1')));
        await _wait(tester);
        expect(find.text('Agendada'), findsOneWidget);

        await tester.pageBack();
        await _wait(tester);
        _changeStatus(container, 1, 'CANCELADA_SOCIO');
        await tester.tap(find.byKey(const Key('appointment-1')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Todavía no pasó la latencia (300 ms): ni el estado viejo ni el nuevo.
        expect(find.byType(AppointmentDetailScreen), findsOneWidget);
        expect(find.text('Agendada'), findsNothing);
        expect(find.text('Cancelada por el socio'), findsNothing);
        await _wait(tester);
        expect(find.text('Cancelada por el socio'), findsOneWidget);
        await unmountApp(tester);
      },
    );

    testWidgets('la lista anterior sigue a la vista mientras se vuelve a '
        'pedir (sin parpadeo)', (tester) async {
      final (container, _) = await _pump(tester);
      await _openMyAppointments(tester, container);
      await goTo(tester, container, '/socio/disponibilidad');
      await _wait(tester);

      container.read(goRouterProvider).go('/socio/consultas');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Todavía no pasó la latencia (300 ms): se ve lo anterior, sin ruedita.
      expect(find.byKey(const Key('appointment-1')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await _wait(tester);
      await unmountApp(tester);
    });
  });

  group('lo que el socio eligió se conserva', () {
    testWidgets('el orden Ascendente y el filtro de Estado siguen puestos al '
        'volver, y la lista es la actual', (tester) async {
      final (container, _) = await _pump(tester);
      await _openMyAppointments(tester, container);
      await _pickStatus(tester, 'Cancelada por el socio');
      await _toggleDirection(tester);
      expect(find.text('Ascendente'), findsOneWidget);
      expect(find.byKey(const Key('appointment-2')), findsOneWidget);
      expect(find.byKey(const Key('appointment-1')), findsNothing);

      _changeStatus(container, 1, 'CANCELADA_SOCIO');
      await goTo(tester, container, '/socio/disponibilidad');
      await _openMyAppointments(tester, container);

      expect(find.text('Ascendente'), findsOneWidget);
      expect(find.text('Cancelada por el socio'), findsWidgets);
      // La consulta 1, que ahora también está cancelada, aparece en el
      // filtro elegido; la 3 (Atendida) sigue fuera.
      expect(find.byKey(const Key('appointment-1')), findsOneWidget);
      expect(find.byKey(const Key('appointment-2')), findsOneWidget);
      expect(find.byKey(const Key('appointment-3')), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('las opciones del filtro de Estado también son las actuales', (
      tester,
    ) async {
      final (container, _) = await _pump(tester);
      await _openMyAppointments(tester, container);
      await tester.tap(find.byKey(const Key('history-filter-status')));
      await tester.pumpAndSettle();
      expect(find.text('Agendada'), findsOneWidget);
      await tester.tap(find.text('Todos').last);
      await tester.pumpAndSettle();

      _changeStatus(container, 1, 'CANCELADA_SOCIO');
      await goTo(tester, container, '/socio/disponibilidad');
      await _openMyAppointments(tester, container);
      await tester.tap(find.byKey(const Key('history-filter-status')));
      await tester.pumpAndSettle();

      expect(find.text('Agendada'), findsNothing);
      expect(find.text('Cancelada por el socio'), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('si falla al volver', () {
    testWidgets('avisa con Reintentar y al reintentar muestra lo actual', (
      tester,
    ) async {
      final (container, repo) = await _pump(tester);
      await _openMyAppointments(tester, container);
      await goTo(tester, container, '/socio/disponibilidad');
      _changeStatus(container, 1, 'CANCELADA_SOCIO');
      repo.failList = true;
      await _openMyAppointments(tester, container);

      expect(find.byKey(const Key('history-error')), findsOneWidget);
      expect(find.text(_loadFailure), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      repo.failList = false;
      await tester.tap(find.text('Reintentar'));
      await _wait(tester);

      expect(find.byKey(const Key('history-error')), findsNothing);
      expect(_title('Dermatología · Cancelada por el socio'), findsOneWidget);
      await unmountApp(tester);
    });
  });

  group('al volver la pestaña o la app a primer plano', () {
    testWidgets(
      'la lista pide una vez visible, ninguna tapada y una al verla',
      (tester) async {
        final (container, repo) = await _pump(tester);
        await _openMyAppointments(tester, container);
        final visible = repo.listCalls;

        backgroundAndReturn(tester);
        await _wait(tester);

        expect(repo.listCalls, visible + 1);

        await goTo(tester, container, '/socio/disponibilidad');
        await _wait(tester);
        final covered = repo.listCalls;
        backgroundAndReturn(tester);
        await _wait(tester);

        expect(repo.listCalls, covered);

        await _openMyAppointments(tester, container);
        expect(repo.listCalls, covered + 1);
        await unmountApp(tester);
      },
    );

    testWidgets(
      'el detalle pide una vez visible, ninguno tapado y uno al verlo',
      (tester) async {
        final (container, repo) = await _pump(tester);
        await _openMyAppointments(tester, container);
        await tester.tap(find.byKey(const Key('appointment-1')));
        await _wait(tester);
        final visible = repo.detailCalls;

        backgroundAndReturn(tester);
        await _wait(tester);

        expect(repo.detailCalls, visible + 1);

        await goTo(tester, container, '/socio/disponibilidad');
        await _wait(tester);
        final covered = repo.detailCalls;
        backgroundAndReturn(tester);
        await _wait(tester);

        expect(repo.detailCalls, covered);

        await goTo(tester, container, '/socio/consultas/1');
        await _wait(tester);
        expect(repo.detailCalls, covered + 1);
        await unmountApp(tester);
      },
    );
  });

  group('a 320 px con Roboto', () {
    setUpAll(loadRoboto);

    testWidgets('la lista al volver y el detalle no desbordan', (tester) async {
      final (container, _) = await _pump(tester, size: const Size(320, 640));
      await _openMyAppointments(tester, container);
      await goTo(tester, container, '/socio/disponibilidad');
      _changeStatus(container, 1, 'CANCELADA_SOCIO');
      await _openMyAppointments(tester, container);

      expect(_title('Dermatología · Cancelada por el socio'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byKey(const Key('appointment-1')));
      await tester.tap(find.byKey(const Key('appointment-1')));
      await _wait(tester);

      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      expect(find.text('Cancelada por el socio'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmountApp(tester);
    });
  });
}
