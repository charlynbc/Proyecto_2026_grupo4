import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/referral.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_repository.dart';
import 'package:agenda_medica/features/medico/models/doctor_appointment_result.dart';
import 'package:agenda_medica/features/medico/providers/doctor_result_repository_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_result_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_appointment_result_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_result_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';

const _missingCondition = 'Escribí la afección que se diagnosticó.';
const _badValidity =
    'La vigencia tiene que ser un número de días entre 1 y 365.';
const _missingSpecialty = 'Elegí la especialidad del pase.';

/// Responde siempre lo mismo, escrito a mano: el 15 atendido con atención 8 y
/// un pase de Cardiología que vence el 24/01/2027, o no se presentó. Anota los
/// pedidos, puede frenarlos con [gate] y falla con los [failures] en orden.
class _FixedRepository implements DoctorResultRepository {
  _FixedRepository({this.gate, List<Object> failures = const []})
    : _failures = [...failures];

  final Completer<void>? gate;
  final List<Object> _failures;
  int calls = 0;
  AppointmentResultRequest? lastRequest;

  @override
  Future<AppointmentResult> register(
    int appointmentId,
    AppointmentResultRequest request,
  ) async {
    calls++;
    lastRequest = request;
    await gate?.future;
    if (_failures.isNotEmpty) throw _failures.removeAt(0);
    final registeredAt = DateTime.utc(2026, 10, 26, 13);
    if (request.outcome == ConsultationOutcome.noShow) {
      return AppointmentResult(
        appointmentId: 15,
        outcome: ConsultationOutcome.noShow,
        attentionId: null,
        registeredAt: registeredAt,
        referrals: const [],
      );
    }
    return AppointmentResult(
      appointmentId: 15,
      outcome: ConsultationOutcome.attended,
      attentionId: 8,
      registeredAt: registeredAt,
      referrals: [
        Referral(
          id: 7,
          specialty: const Specialty(
            id: 2,
            name: 'Cardiología',
            requiresReferral: true,
          ),
          issuedAt: registeredAt,
          expiresOn: DateTime.utc(2027, 1, 24),
        ),
      ],
    );
  }
}

/// El catálogo falla la primera vez que se pide y después responde.
class _FlakySpecialties implements SpecialtyRepository {
  int calls = 0;

  @override
  Future<List<Specialty>> list() async {
    calls++;
    if (calls == 1) throw const ApiException();
    return const [
      Specialty(id: 2, name: 'Cardiología', requiresReferral: true),
    ];
  }

  @override
  Future<Specialty> create({
    required String name,
    required bool requiresReferral,
  }) => throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester,
  _FixedRepository repository, {
  String? patientName,
  SpecialtyRepository? specialties,
}) async {
  await pumpAdminScreens(
    tester,
    size: const Size(900, 3000),
    initialLocation: doctorResultLocation(15, patientName: patientName),
    routes: [
      GoRoute(
        path: kDoctorResultPath,
        builder: (_, state) => DoctorAppointmentResultScreen(
          appointmentId: 15,
          patientName: state.uri.queryParameters['paciente'],
        ),
      ),
      GoRoute(
        path: '/medico/turnos',
        builder: (_, _) => const Scaffold(body: Text('Pantalla de turnos')),
      ),
    ],
    overrides: [
      doctorResultRepositoryProvider.overrideWith((ref) async => repository),
      specialtyRepositoryProvider.overrideWith(
        (ref) async =>
            specialties ??
            FakeSpecialtyRepository(
              FakeAdminDatabase(),
              latency: Duration.zero,
            ),
      ),
    ],
  );
}

Finder _key(String key) => find.byKey(Key(key));

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(_key(key), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pickSpecialty(WidgetTester tester, String name) async {
  await _tap(tester, _key('referral-specialty'));
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _addReferral(
  WidgetTester tester,
  String name, {
  String? days,
}) async {
  await _pickSpecialty(tester, name);
  if (days != null) await _enter(tester, 'referral-validity', days);
  await _tap(tester, _key('referral-add'));
}

/// Los nombres que ofrece el desplegable de especialidades.
List<String> _offered(WidgetTester tester) => [
  for (final item in tester.widgetList<DropdownMenuItem<int>>(
    find.byType(DropdownMenuItem<int>, skipOffstage: false),
  ))
    (item.child as Text).data!,
];

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(_key(key)).controller!.text;

void main() {
  group('formulario', () {
    testWidgets('con Atendida se ven los campos y los pases; con No se '
        'presentó se ocultan', (tester) async {
      await _pump(tester, _FixedRepository());

      expect(find.text('Resultado de la consulta'), findsOneWidget);
      expect(_key('result-condition'), findsOneWidget);
      expect(_key('result-treatment'), findsOneWidget);
      expect(_key('result-notes'), findsOneWidget);
      expect(find.text('Pases'), findsOneWidget);
      expect(_key('referral-specialty'), findsOneWidget);
      expect(_key('referral-add'), findsOneWidget);

      await _enter(tester, 'result-condition', 'gripe');
      await _tap(tester, find.text('No se presentó'));

      expect(_key('result-condition'), findsNothing);
      expect(_key('result-treatment'), findsNothing);
      expect(_key('result-notes'), findsNothing);
      expect(find.text('Pases'), findsNothing);
      expect(_key('referral-specialty'), findsNothing);
      expect(_key('result-submit'), findsOneWidget);

      await _tap(tester, find.text('Atendida'));

      expect(_fieldText(tester, 'result-condition'), 'gripe');
    });

    testWidgets('el desplegable ofrece solo Cardiología y Dermatología, y '
        'tras agregar Cardiología ya no la ofrece', (tester) async {
      await _pump(tester, _FixedRepository());

      expect(_offered(tester), ['Cardiología', 'Dermatología']);

      await _addReferral(tester, 'Cardiología');

      expect(_offered(tester), ['Dermatología']);
      expect(_key('remove-referral-2'), findsOneWidget);
    });

    testWidgets('quitar un pase vuelve a ofrecer su especialidad', (
      tester,
    ) async {
      await _pump(tester, _FixedRepository());
      await _addReferral(tester, 'Cardiología');

      await _tap(tester, _key('remove-referral-2'));

      expect(_key('remove-referral-2'), findsNothing);
      expect(_offered(tester), ['Cardiología', 'Dermatología']);
    });

    testWidgets('agregar un pase sin elegir especialidad lo avisa', (
      tester,
    ) async {
      await _pump(tester, _FixedRepository());

      await _tap(tester, _key('referral-add'));

      expect(find.text(_missingSpecialty), findsOneWidget);
      expect(_key('remove-referral-2'), findsNothing);
    });

    testWidgets('una vigencia fuera de rango se avisa y no agrega el pase', (
      tester,
    ) async {
      await _pump(tester, _FixedRepository());

      await _addReferral(tester, 'Cardiología', days: '366');

      expect(find.text(_badValidity), findsOneWidget);
      expect(_key('remove-referral-2'), findsNothing);
    });

    testWidgets('si el catálogo no carga, ofrece reintentar', (tester) async {
      final specialties = _FlakySpecialties();
      await _pump(tester, _FixedRepository(), specialties: specialties);

      expect(
        find.text('No pudimos cargar las especialidades.'),
        findsOneWidget,
      );

      await _tap(tester, find.text('Reintentar'));

      expect(find.text('No pudimos cargar las especialidades.'), findsNothing);
      expect(_offered(tester), ['Cardiología']);
    });

    testWidgets('con el nombre del paciente, el encabezado lo muestra', (
      tester,
    ) async {
      await _pump(tester, _FixedRepository(), patientName: 'Carlos Rodríguez');

      expect(find.text('Paciente: Carlos Rodríguez'), findsOneWidget);
    });

    testWidgets('sin nombre de paciente no hay renglón de paciente', (
      tester,
    ) async {
      await _pump(tester, _FixedRepository());

      expect(find.textContaining('Paciente:'), findsNothing);
    });

    testWidgets('la flecha de volver lleva a los turnos del médico', (
      tester,
    ) async {
      await _pump(tester, _FixedRepository());

      await _tap(tester, find.byTooltip('Volver a mis turnos'));

      expect(find.text('Pantalla de turnos'), findsOneWidget);
    });
  });

  group('envío', () {
    testWidgets('registrar sin afección no abre el diálogo ni llama al '
        'repositorio, y marca el campo', (tester) async {
      final repository = _FixedRepository();
      await _pump(tester, repository);

      await _tap(tester, _key('result-submit'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.calls, 0);
      expect(find.text(_missingCondition), findsOneWidget);
    });

    testWidgets('con una especialidad elegida y sin agregar, registrar avisa '
        'y no abre el diálogo ni llama al repositorio', (tester) async {
      final repository = _FixedRepository();
      await _pump(tester, repository);
      await _enter(tester, 'result-condition', 'gripe');
      await _pickSpecialty(tester, 'Dermatología');

      await _tap(tester, _key('result-submit'));

      expect(
        find.text(
          'Tocá Agregar pase para incluir esa especialidad o quitá la '
          'selección.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.calls, 0);
    });

    testWidgets('una afección de solo espacios tampoco abre el diálogo', (
      tester,
    ) async {
      final repository = _FixedRepository();
      await _pump(tester, repository);
      await _enter(tester, 'result-condition', '   ');

      await _tap(tester, _key('result-submit'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.calls, 0);
    });

    testWidgets('pasar a No se presentó quita la marca de la afección', (
      tester,
    ) async {
      await _pump(tester, _FixedRepository());
      await _tap(tester, _key('result-submit'));
      expect(find.text(_missingCondition), findsOneWidget);

      await _tap(tester, find.text('No se presentó'));
      await _tap(tester, find.text('Atendida'));

      expect(find.text(_missingCondition), findsNothing);
    });

    testWidgets('el diálogo avisa que no se puede cambiar y resume Atendida '
        'con sus pases', (tester) async {
      await _pump(tester, _FixedRepository());
      await _enter(tester, 'result-condition', 'gripe');
      await _addReferral(tester, 'Cardiología');
      await _addReferral(tester, 'Dermatología');

      await _tap(tester, _key('result-submit'));

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('no se puede cambiar'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining('Atendida con 2 pases'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el diálogo resume No se presentó', (tester) async {
      await _pump(tester, _FixedRepository());
      await _tap(tester, find.text('No se presentó'));

      await _tap(tester, _key('result-submit'));

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('No se presentó.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancelar el diálogo no envía nada y deja el formulario como '
        'estaba', (tester) async {
      final repository = _FixedRepository();
      await _pump(tester, repository);
      await _enter(tester, 'result-condition', 'gripe');
      await _addReferral(tester, 'Cardiología');
      await _tap(tester, _key('result-submit'));
      expect(find.byType(AlertDialog), findsOneWidget);

      await _tap(tester, _key('confirm-result-cancel'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(repository.calls, 0);
      expect(find.text('Resultado registrado'), findsNothing);
      expect(_fieldText(tester, 'result-condition'), 'gripe');
      expect(_key('remove-referral-2'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_key('result-submit')).onPressed,
        isNotNull,
      );
    });

    testWidgets('confirmar envía una sola vez, aunque se toque dos veces', (
      tester,
    ) async {
      final repository = _FixedRepository();
      await _pump(tester, repository);
      await _enter(tester, 'result-condition', 'gripe');
      await _tap(tester, _key('result-submit'));

      await tester.tap(_key('confirm-result-ok'));
      await tester.tap(_key('confirm-result-ok'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.lastRequest!.toJson(), {
        'resultado': 'ATENDIDA',
        'afeccion': 'gripe',
      });
      expect(find.text('Resultado registrado'), findsOneWidget);
    });

    testWidgets('mientras se envía el botón está deshabilitado', (
      tester,
    ) async {
      final gate = Completer<void>();
      final repository = _FixedRepository(gate: gate);
      await _pump(tester, repository);
      await _enter(tester, 'result-condition', 'gripe');
      await _tap(tester, _key('result-submit'));

      await tester.tap(_key('confirm-result-ok'));
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<FilledButton>(_key('result-submit')).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(repository.calls, 1);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Resultado registrado'), findsOneWidget);
      expect(repository.calls, 1);
    });
  });

  group('resultado del servidor', () {
    testWidgets('éxito atendida: confirmación con el pase emitido', (
      tester,
    ) async {
      await _pump(tester, _FixedRepository());
      await _enter(tester, 'result-condition', 'gripe');
      await _addReferral(tester, 'Cardiología');
      await _tap(tester, _key('result-submit'));

      await _tap(tester, _key('confirm-result-ok'));

      expect(find.text('Resultado registrado'), findsOneWidget);
      expect(find.text('Pases emitidos'), findsOneWidget);
      expect(find.text('Cardiología'), findsOneWidget);
      expect(find.text('Vence el 24/01/2027'), findsOneWidget);
      expect(_key('result-condition'), findsNothing);
      expect(_key('result-submit'), findsNothing);

      await _tap(tester, _key('result-back-to-shifts'));

      expect(find.text('Pantalla de turnos'), findsOneWidget);
    });

    testWidgets('éxito No se presentó: confirmación sin pases', (tester) async {
      await _pump(tester, _FixedRepository());
      await _tap(tester, find.text('No se presentó'));
      await _tap(tester, _key('result-submit'));

      await _tap(tester, _key('confirm-result-ok'));

      expect(find.text('Resultado registrado'), findsOneWidget);
      expect(find.text('Pases emitidos'), findsNothing);
      expect(find.textContaining('Vence el'), findsNothing);
      expect(find.text('Cardiología'), findsNothing);
      expect(_key('result-back-to-shifts'), findsOneWidget);
    });

    testWidgets('PASE_DUPLICADO muestra su mensaje, conserva lo escrito y '
        'permite reintentar', (tester) async {
      final repository = _FixedRepository(
        failures: [const DuplicateReferralException()],
      );
      await _pump(tester, repository);
      await _enter(tester, 'result-condition', 'gripe');
      await _addReferral(tester, 'Cardiología');
      await _tap(tester, _key('result-submit'));
      await _tap(tester, _key('confirm-result-ok'));

      expect(repository.calls, 1);
      expect(
        find.descendant(
          of: _key('result-error'),
          matching: find.textContaining('ya tiene un pase vigente'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PASE_DUPLICADO'), findsNothing);
      expect(find.text('Resultado registrado'), findsNothing);
      expect(_fieldText(tester, 'result-condition'), 'gripe');
      expect(_key('remove-referral-2'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_key('result-submit')).onPressed,
        isNotNull,
      );

      await _tap(tester, _key('remove-referral-2'));
      await _tap(tester, _key('result-submit'));
      await _tap(tester, _key('confirm-result-ok'));

      expect(repository.calls, 2);
      expect(find.text('Resultado registrado'), findsOneWidget);
      expect(_key('result-error'), findsNothing);
    });
  });
}
