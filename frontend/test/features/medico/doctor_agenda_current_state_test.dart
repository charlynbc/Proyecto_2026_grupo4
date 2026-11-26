import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/medico/models/doctor_shift.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_shift_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_shifts_screen.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/load_roboto.dart';

const _loadFailure = 'Fallo controlado al actualizar la agenda.';
const _shiftsPath = '/medico/turnos';
const _awayPath = '/medico/atenciones';

const _before = 'Consultorio 1 · 2 de 3 números reservados';
const _after = 'Consultorio 1 · 0 de 3 números reservados · Suspendido';

class _DoctorSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'medico-agenda-estado-actual-prueba',
    role: UserRole.medico,
  );
}

/// El repositorio falso de la agenda con el conteo de los pedidos de turnos y
/// la posibilidad de frenar o hacer fallar el próximo.
class _ControlledShiftRepository extends FakeDoctorShiftRepository {
  final dates = <String>[];
  bool failNext = false;
  Completer<void>? _gate;

  int get shiftCalls => dates.length;

  /// Frena el próximo pedido de turnos.
  Completer<void> delayNext() => _gate = Completer<void>();

  void releasePending() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<List<DoctorShift>> listShifts(String date) async {
    dates.add(date);
    final gate = _gate;
    if (gate != null) {
      _gate = null;
      await gate.future;
    }
    if (failNext) {
      failNext = false;
      throw const ApiException(_loadFailure);
    }
    return super.listShifts(date);
  }
}

// El sondeo deja un temporizador vivo: se suelta dentro del test, antes de que
// el framework revise los temporizadores pendientes.
Future<void> Function()? _cleanup;

void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await _cleanup?.call();
      _cleanup = null;
    }
  });
}

class _Harness {
  const _Harness({
    required this.container,
    required this.router,
    required this.repo,
  });

  final ProviderContainer container;
  final GoRouter router;
  final _ControlledShiftRepository repo;

  DoctorAgendaState get state => container.read(doctorAgendaControllerProvider);
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(1100, 1400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = _ControlledShiftRepository();
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_DoctorSession.new),
      doctorShiftRepositoryProvider.overrideWith((ref) async => repo),
      specialtiesProvider.overrideWith(
        (ref) async => const [
          Specialty(id: 1, name: 'Medicina General', requiresReferral: false),
        ],
      ),
      latestAnnouncementsProvider.overrideWith((ref) async => []),
    ],
  );
  final router = container.read(goRouterProvider)..go(_shiftsPath);
  _cleanup = () async {
    repo.releasePending();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  };

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        locale: const Locale('es', 'UY'),
        supportedLocales: const [Locale('es', 'UY')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await _settle(tester);
  expect(find.byType(DoctorShiftsScreen), findsOneWidget);
  expect(find.text(_before), findsOneWidget);
  expect(repo.shiftCalls, 1);
  return _Harness(container: container, router: router, repo: repo);
}

Future<void> _leave(WidgetTester tester, _Harness harness) async {
  harness.router.go(_awayPath);
  await _settle(tester);
}

Future<void> _pumpUntilShiftCalls(
  WidgetTester tester,
  _ControlledShiftRepository repo,
  int expected,
) async {
  for (var i = 0; i < 12 && repo.shiftCalls < expected; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  _test('al volver desde otra sección muestra el cambio sin esperar los '
      '15 segundos', (tester) async {
    final harness = await _pump(tester);

    await _leave(tester, harness);
    harness.repo.suspendShift(1);
    harness.router.go(_shiftsPath);
    await _settle(tester);

    expect(harness.repo.shiftCalls, 2);
    expect(find.text(_after), findsOneWidget);
    expect(find.text(_before), findsNothing);
  });

  _test('al volver hace un pedido y conserva la lista durante la '
      'carga', (tester) async {
    final harness = await _pump(tester);
    await _leave(tester, harness);
    harness.repo.suspendShift(1);
    final gate = harness.repo.delayNext();

    harness.router.go(_shiftsPath);
    await _pumpUntilShiftCalls(tester, harness.repo, 2);

    expect(harness.repo.shiftCalls, 2);
    expect(find.text(_before), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(harness.repo.shiftCalls, 2);
    expect(find.text(_after), findsOneWidget);
  });

  _test('al volver del segundo plano hace un solo pedido', (tester) async {
    final harness = await _pump(tester);
    harness.repo.suspendShift(1);

    backgroundAndReturn(tester);
    await _settle(tester);

    expect(harness.repo.shiftCalls, 2);
    expect(find.text(_after), findsOneWidget);
  });

  _test('si falla al volver muestra el aviso con los datos anteriores y '
      'el sondeo lo recupera a los 15 segundos', (tester) async {
    final harness = await _pump(tester);
    await _leave(tester, harness);
    harness.repo.suspendShift(1);
    harness.repo.failNext = true;

    harness.router.go(_shiftsPath);
    await _settle(tester);

    expect(harness.repo.shiftCalls, 2);
    expect(find.byKey(const Key('doctor-refresh-error')), findsOneWidget);
    expect(find.textContaining(_loadFailure), findsOneWidget);
    expect(find.byKey(const Key('doctor-error')), findsNothing);
    expect(find.byKey(const Key('doctor-retry')), findsNothing);
    expect(find.text(_before), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    await _settle(tester);

    expect(harness.repo.shiftCalls, 3);
    expect(find.byKey(const Key('doctor-refresh-error')), findsNothing);
    expect(find.text(_after), findsOneWidget);
  });

  _test('al volver conserva la fecha, el turno, el filtro y el orden', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final controller = harness.container.read(
      doctorAgendaControllerProvider.notifier,
    );
    await controller.setDate('2026-11-20');
    await _settle(tester);
    await tester.tap(find.byKey(const Key('doctor-shift-1')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('arrived-filter-yes')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('doctor-direction')));
    await _settle(tester);
    expect(find.text('Fecha: 20/11/2026'), findsOneWidget);
    expect(harness.state.selectedShiftId, 1);
    expect(harness.state.arrivedFilter, isTrue);
    expect(harness.state.ascending, isFalse);
    final calls = harness.repo.shiftCalls;

    await _leave(tester, harness);
    harness.router.go(_shiftsPath);
    await _settle(tester);

    expect(harness.repo.shiftCalls, calls + 1);
    expect(harness.repo.dates.last, '2026-11-20');
    expect(find.text('Fecha: 20/11/2026'), findsOneWidget);
    expect(harness.state.date, '2026-11-20');
    expect(harness.state.selectedShiftId, 1);
    expect(harness.state.arrivedFilter, isTrue);
    expect(harness.state.ascending, isFalse);
    expect(find.text('Ana Pérez · CI 1.111.111-1'), findsOneWidget);
  });

  group('sondeo de 15 segundos', () {
    _test('sigue pidiendo cada 15 segundos', (tester) async {
      final harness = await _pump(tester);

      await tester.pump(const Duration(seconds: 15));
      await _settle(tester);
      expect(harness.repo.shiftCalls, 2);

      await tester.pump(const Duration(seconds: 15));
      await _settle(tester);
      expect(harness.repo.shiftCalls, 3);
    });

    _test('un tick con el pedido de volver en vuelo no lo duplica', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _leave(tester, harness);
      final gate = harness.repo.delayNext();
      harness.router.go(_shiftsPath);
      await _pumpUntilShiftCalls(tester, harness.repo, 2);
      expect(harness.repo.shiftCalls, 2);

      // El sondeo cae mientras el pedido de volver todavía no respondió.
      await tester.pump(const Duration(seconds: 15));
      expect(harness.repo.shiftCalls, 2);

      gate.complete();
      await _settle(tester);
      expect(harness.repo.shiftCalls, 2);
    });
  });

  _test('a 320 px con texto al doble el aviso de error se ve dentro del '
      'ancho', (tester) async {
    await loadRoboto();
    final harness = await _pump(
      tester,
      size: const Size(320, 1400),
      textScale: 2,
    );
    await _leave(tester, harness);
    harness.repo.failNext = true;

    harness.router.go(_shiftsPath);
    await _settle(tester);

    final banner = find.byKey(const Key('doctor-refresh-error'));
    expect(banner, findsOneWidget);
    expect(find.text(_before), findsOneWidget);
    final rect = tester.getRect(banner);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });
}
