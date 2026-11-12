import 'dart:async' show unawaited;

import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:agenda_medica/features/consultorios/screens/new_clinic_screen.dart';
import 'package:agenda_medica/features/estadisticas/screens/statistics_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_appointment_result_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_history_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_patient_history_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_referrals_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_result_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_shifts_screen.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/especialidades/screens/edit_specialty_screen.dart';
import 'package:agenda_medica/features/especialidades/screens/new_specialty_screen.dart';
import 'package:agenda_medica/features/especialidades/screens/specialties_screen.dart';
import 'package:agenda_medica/features/turnos/screens/new_weekly_shift_screen.dart';
import 'package:agenda_medica/features/turnos/screens/reinstate_shifts_screen.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/shifts_screen.dart';
import 'package:agenda_medica/features/turnos/screens/weekly_shift_detail_screen.dart';
import 'package:agenda_medica/features/usuarios/screens/new_user_screen.dart';
import 'package:agenda_medica/features/usuarios/screens/user_routes.dart';
import 'package:agenda_medica/features/usuarios/screens/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> _loginAs(
  WidgetTester tester,
  ProviderContainer container,
  UserRole role,
) async {
  final person = TestData.people.firstWhere((p) => p.role == role.apiValue);
  final repo = await container.read(authRepositoryProvider.future);
  final done = repo.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.forRole(role),
  );
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ruta real de corrección abre un consultorio válido', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.administrador);
    await goTo(tester, container, '/admin/consultorios/1/corregir');
    expect(find.text('Corregir consultorio'), findsOneWidget);
    expect(find.text('Consultorio 3'), findsOneWidget);
    await unmountApp(tester);
  });

  for (final id in ['0', '-3', 'abc']) {
    testWidgets('ruta real de corrección con id $id no encontrado', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.administrador);
      await goTo(tester, container, '/admin/consultorios/$id/corregir');
      expect(find.text('No encontramos ese consultorio.'), findsOneWidget);
      await unmountApp(tester);
    });
  }

  group('redirectFor', () {
    const checking = SessionState(status: SessionStatus.checking);
    const anonymous = SessionState();
    const socio = SessionState(
      status: SessionStatus.authenticated,
      accessToken: 't',
      role: UserRole.socio,
    );

    test('verificando la sesión conserva el enlace de primer ingreso', () {
      expect(redirectFor(checking, Uri.parse('/primer-ingreso?token=x')), null);
      expect(redirectFor(checking, Uri.parse('/login')), '/');
      expect(redirectFor(checking, Uri.parse('/socio/consultas')), '/');
    });

    test('sin sesión solo se entra a login y primer ingreso', () {
      expect(redirectFor(anonymous, Uri.parse('/login')), null);
      expect(redirectFor(anonymous, Uri.parse('/admin/usuarios')), '/login');
      expect(redirectFor(anonymous, Uri.parse('/cuenta/editar')), '/login');
      expect(
        redirectFor(anonymous, Uri.parse('/primer-ingreso')),
        '/primer-ingreso/solicitar',
      );
      expect(
        redirectFor(anonymous, Uri.parse('/primer-ingreso?token=abc')),
        null,
      );
    });

    test('con sesión no se vuelve al login ni a otro rol', () {
      expect(redirectFor(socio, Uri.parse('/login')), UserRole.socio.homePath);
      expect(
        redirectFor(socio, Uri.parse('/primer-ingreso?token=x')),
        UserRole.socio.homePath,
      );
      expect(
        redirectFor(socio, Uri.parse('/medico/turnos')),
        UserRole.socio.homePath,
      );
      expect(redirectFor(socio, Uri.parse('/socio')), UserRole.socio.homePath);
      expect(redirectFor(socio, Uri.parse('/socio/historia')), null);
    });

    test('la edición de cuenta admite una sesión de cada rol', () {
      for (final role in UserRole.values) {
        final session = SessionState(
          status: SessionStatus.authenticated,
          accessToken: 't',
          role: role,
        );
        expect(redirectFor(session, Uri.parse('/cuenta/editar')), isNull);
      }
    });
  });

  group('redirectFor en la recuperación de contraseña (RF-05)', () {
    const checking = SessionState(status: SessionStatus.checking);
    const anonymous = SessionState();

    test('verificando la sesión no manda la recuperación a la carga', () {
      expect(redirectFor(checking, Uri.parse('/recuperacion?token=x')), null);
      expect(redirectFor(checking, Uri.parse('/recuperacion/solicitar')), null);
    });

    test('sin sesión se entra a las dos rutas y el token no se pierde', () {
      expect(
        redirectFor(anonymous, Uri.parse('/recuperacion?token=abc')),
        null,
      );
      expect(
        redirectFor(anonymous, Uri.parse('/recuperacion/solicitar')),
        null,
      );
      expect(
        redirectFor(
          anonymous,
          Uri.parse('/recuperacion/solicitar?acceso=empleado'),
        ),
        null,
      );
    });

    test('sin sesión, /recuperacion sin token o con token vacío va a pedir '
        'el enlace', () {
      expect(
        redirectFor(anonymous, Uri.parse('/recuperacion')),
        '/recuperacion/solicitar',
      );
      expect(
        redirectFor(anonymous, Uri.parse('/recuperacion?token=')),
        '/recuperacion/solicitar',
      );
    });

    test('con sesión de cada rol, las dos rutas van al inicio del rol', () {
      for (final role in UserRole.values) {
        final session = SessionState(
          status: SessionStatus.authenticated,
          accessToken: 't',
          role: role,
        );
        expect(
          redirectFor(session, Uri.parse('/recuperacion?token=x')),
          role.homePath,
          reason: role.name,
        );
        expect(
          redirectFor(session, Uri.parse('/recuperacion/solicitar')),
          role.homePath,
          reason: role.name,
        );
      }
    });

    test('el login y el primer ingreso no cambian', () {
      expect(redirectFor(anonymous, Uri.parse('/login')), null);
      expect(
        redirectFor(anonymous, Uri.parse('/primer-ingreso?token=t')),
        null,
      );
      expect(
        redirectFor(anonymous, Uri.parse('/primer-ingreso')),
        '/primer-ingreso/solicitar',
      );
      expect(redirectFor(checking, Uri.parse('/login')), '/');
    });
  });

  group('redirectFor en la confirmación del cambio de correo (RF-06)', () {
    const checking = SessionState(status: SessionStatus.checking);
    const anonymous = SessionState();

    test('verificando la sesión no manda el enlace a la carga', () {
      expect(redirectFor(checking, Uri.parse('/cambio-correo?token=x')), null);
    });

    test('sin sesión el enlace con token se queda', () {
      expect(
        redirectFor(anonymous, Uri.parse('/cambio-correo?token=abc')),
        null,
      );
    });

    test('con sesión de cada rol el enlace con token se queda', () {
      for (final role in UserRole.values) {
        final session = SessionState(
          status: SessionStatus.authenticated,
          accessToken: 't',
          role: role,
        );
        expect(
          redirectFor(session, Uri.parse('/cambio-correo?token=abc')),
          null,
          reason: role.name,
        );
      }
    });

    test('sin token o con el token vacío va a /, con o sin sesión', () {
      const socio = SessionState(
        status: SessionStatus.authenticated,
        accessToken: 't',
        role: UserRole.socio,
      );
      for (final session in [checking, anonymous, socio]) {
        expect(redirectFor(session, Uri.parse('/cambio-correo')), '/');
        expect(redirectFor(session, Uri.parse('/cambio-correo?token=')), '/');
      }
    });

    test('la recuperación y el login no cambian', () {
      expect(redirectFor(anonymous, Uri.parse('/recuperacion?token=x')), null);
      expect(
        redirectFor(anonymous, Uri.parse('/recuperacion')),
        '/recuperacion/solicitar',
      );
      expect(redirectFor(anonymous, Uri.parse('/login')), null);
      expect(redirectFor(checking, Uri.parse('/login')), '/');
    });
  });

  testWidgets('cada rol entra a su home y ve solo sus secciones', (
    tester,
  ) async {
    for (final role in UserRole.values) {
      final container = await pumpApp(tester);
      expect(locationOf(container), '/login');

      await _loginAs(tester, container, role);

      expect(locationOf(container), role.homePath, reason: role.name);
      final labels = role.sections.map((s) => s.label).toSet();
      if (role.sections.length > 1) {
        for (final label in labels) {
          if (role == UserRole.socio && label == 'Inicio') continue;
          expect(find.text(label), findsWidgets, reason: '${role.name}/$label');
        }
      }
      // Ninguna sección de otro rol.
      for (final other in UserRole.values.where((r) => r != role)) {
        for (final section in other.sections) {
          if (labels.contains(section.label)) continue;
          expect(find.text(section.label), findsNothing);
        }
      }
      // Lo que no existe todavía va a "Próximamente"; la home del
      // administrador ya es el padrón de usuarios y la del funcionario, la
      // consulta de turnos.
      final hasHomeScreen =
          role == UserRole.administrador ||
          role == UserRole.funcionario ||
          role == UserRole.medico ||
          role == UserRole.socio;
      expect(
        find.text('Próximamente'),
        hasHomeScreen ? findsNothing : findsOneWidget,
        reason: role.name,
      );
      if (role == UserRole.medico) {
        await unmountApp(tester);
        container.invalidate(doctorAgendaControllerProvider);
      }
    }
    await unmountApp(tester);
  });

  testWidgets(
    'el médico conserva Mis turnos como inicio y tiene acceso a Cartelera',
    (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Cartelera'), findsOneWidget);
      expect(find.text('Pases'), findsOneWidget);
      expect(find.text('Atenciones'), findsOneWidget);
      expect(find.byType(DoctorShiftsScreen), findsOneWidget);
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    },
  );

  testWidgets('el médico llega a Pases desde el menú y por su ruta', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.medico);

    await tester.tap(find.text('Pases'));
    await tester.pumpAndSettle();

    expect(locationOf(container), '/medico/pases');
    expect(find.byType(DoctorReferralsScreen), findsOneWidget);
    expect(find.text('Pases emitidos'), findsOneWidget);
    expect(find.text('Próximamente'), findsNothing);
    await unmountApp(tester);
    container.invalidate(doctorAgendaControllerProvider);
  });

  testWidgets('un rol no puede entrar a las rutas de otro', (tester) async {
    for (final role in UserRole.values) {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, role);

      for (final other in UserRole.values.where((r) => r != role)) {
        for (final section in other.sections) {
          await goTo(tester, container, other.sectionPath(section));
          expect(
            locationOf(container),
            role.homePath,
            reason: '${role.name} → ${other.sectionPath(section)}',
          );
        }
        await goTo(tester, container, other.routePrefix);
        expect(locationOf(container), role.homePath);
      }

      // Sus propias secciones sí.
      final last = role.sections.last;
      await goTo(tester, container, role.sectionPath(last));
      expect(locationOf(container), role.sectionPath(last));
    }
    await unmountApp(tester);
  });

  group('área del médico: resultado de la consulta', () {
    test('la ruta del resultado la arma con el nombre codificado', () {
      expect(
        doctorResultLocation(15, patientName: 'Carlos Rodríguez'),
        '/medico/consultas/15/resultado?paciente=Carlos%20Rodr%C3%ADguez',
      );
      expect(doctorResultLocation(15), '/medico/consultas/15/resultado');
    });

    test('sin sesión va a login y con otro rol a su home', () {
      const socio = SessionState(
        status: SessionStatus.authenticated,
        accessToken: 't',
        role: UserRole.socio,
      );
      const medico = SessionState(
        status: SessionStatus.authenticated,
        accessToken: 't',
        role: UserRole.medico,
      );
      final uri = Uri.parse('/medico/consultas/15/resultado');

      expect(redirectFor(const SessionState(), uri), '/login');
      expect(redirectFor(socio, uri), UserRole.socio.homePath);
      expect(redirectFor(medico, uri), null);
    });

    testWidgets('un médico llega a la pantalla con el id y el paciente', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      await goTo(
        tester,
        container,
        '/medico/consultas/15/resultado?paciente=Carlos%20Rodr%C3%ADguez',
      );

      expect(find.byType(DoctorAppointmentResultScreen), findsOneWidget);
      final screen = tester.widget<DoctorAppointmentResultScreen>(
        find.byType(DoctorAppointmentResultScreen),
      );
      expect(screen.appointmentId, 15);
      expect(screen.patientName, 'Carlos Rodríguez');
      expect(find.text('Paciente: Carlos Rodríguez'), findsOneWidget);
      expect(find.text('Página no encontrada'), findsNothing);
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    });

    testWidgets('sin ?paciente= la pantalla abre sin nombre', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      await goTo(tester, container, '/medico/consultas/15/resultado');

      final screen = tester.widget<DoctorAppointmentResultScreen>(
        find.byType(DoctorAppointmentResultScreen),
      );
      expect(screen.patientName, isNull);
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    });

    testWidgets('un socio que entra a la ruta vuelve a su home', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.socio);

      await goTo(tester, container, '/medico/consultas/15/resultado');

      expect(locationOf(container), UserRole.socio.homePath);
      expect(find.byType(DoctorAppointmentResultScreen), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('un id que no es un número vuelve a "Mis turnos"', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      for (final bad in ['abc', '0', '1x', '-']) {
        await goTo(tester, container, '/medico/consultas/$bad/resultado');
        expect(locationOf(container), '/medico/turnos', reason: bad);
        expect(find.byType(DoctorShiftsScreen), findsOneWidget, reason: bad);
        expect(find.byType(DoctorAppointmentResultScreen), findsNothing);
      }
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    });
  });

  group('área del médico: historia clínica previa del paciente', () {
    testWidgets('un id que no es un número positivo vuelve a "Mis turnos"', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      for (final bad in ['abc', '0', '1x', '-', '-2']) {
        await goTo(tester, container, '/medico/pacientes/$bad/historia');
        expect(locationOf(container), '/medico/turnos', reason: bad);
        expect(find.byType(DoctorShiftsScreen), findsOneWidget, reason: bad);
        expect(find.byType(DoctorPatientHistoryScreen), findsNothing);
      }
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    });

    testWidgets('un médico llega a la historia con el id y el paciente', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      await goTo(
        tester,
        container,
        '/medico/pacientes/101/historia?paciente=Ana%20P%C3%A9rez',
      );

      expect(find.byType(DoctorPatientHistoryScreen), findsOneWidget);
      final screen = tester.widget<DoctorPatientHistoryScreen>(
        find.byType(DoctorPatientHistoryScreen),
      );
      expect(screen.socioId, 101);
      expect(screen.patientName, 'Ana Pérez');
      expect(find.text('Paciente: Ana Pérez'), findsOneWidget);
      expect(find.text('Página no encontrada'), findsNothing);
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    });

    testWidgets('un socio que entra a la ruta vuelve a su home', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.socio);

      await goTo(tester, container, '/medico/pacientes/101/historia');

      expect(locationOf(container), UserRole.socio.homePath);
      expect(find.byType(DoctorPatientHistoryScreen), findsNothing);
      await unmountApp(tester);
    });

    testWidgets('la flecha de volver sin pila lleva a "Mis turnos"', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      // Se entra directo a la URL: no hay nada debajo para volver.
      await goTo(
        tester,
        container,
        '/medico/pacientes/101/historia?paciente=Ana%20P%C3%A9rez',
      );
      expect(find.byType(DoctorPatientHistoryScreen), findsOneWidget);
      expect(container.read(goRouterProvider).canPop(), isFalse);

      await tester.tap(find.byTooltip('Volver a mis turnos'));
      await tester.pumpAndSettle();

      expect(locationOf(container), '/medico/turnos');
      expect(find.byType(DoctorShiftsScreen), findsOneWidget);
      expect(find.byType(DoctorPatientHistoryScreen), findsNothing);
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    });

    testWidgets('la flecha de volver con pila desde "Mis turnos" vuelve a '
        '"Mis turnos"', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);
      await goTo(tester, container, '/medico/turnos');

      // Como lo hace el botón de la historia en la agenda: un push encima.
      unawaited(
        container
            .read(goRouterProvider)
            .push(doctorPatientHistoryLocation(101, patientName: 'Ana Pérez')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DoctorPatientHistoryScreen), findsOneWidget);
      expect(container.read(goRouterProvider).canPop(), isTrue);

      await tester.tap(find.byTooltip('Volver a mis turnos'));
      await tester.pumpAndSettle();

      expect(locationOf(container), '/medico/turnos');
      expect(find.byType(DoctorShiftsScreen), findsOneWidget);
      expect(find.byType(DoctorPatientHistoryScreen), findsNothing);
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    });

    testWidgets('la flecha de volver con pila vuelve a la pantalla de donde '
        'se vino, no siempre a "Mis turnos"', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);
      await goTo(tester, container, '/medico/pases');
      expect(find.byType(DoctorReferralsScreen), findsOneWidget);

      unawaited(
        container
            .read(goRouterProvider)
            .push(doctorPatientHistoryLocation(101, patientName: 'Ana Pérez')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DoctorPatientHistoryScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Volver a mis turnos'));
      await tester.pumpAndSettle();

      // Con pila el botón hace pop: vuelve a Pases, de donde se vino.
      expect(locationOf(container), '/medico/pases');
      expect(find.byType(DoctorReferralsScreen), findsOneWidget);
      expect(find.byType(DoctorShiftsScreen), findsNothing);
      expect(find.byType(DoctorPatientHistoryScreen), findsNothing);
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    });
  });

  group('área del administrador', () {
    testWidgets('cada sección abre su pantalla', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.administrador);
      expect(find.byType(UsersScreen), findsOneWidget);

      final screens = {
        kUsersPath: find.byType(UsersScreen),
        kSpecialtiesPath: find.byType(SpecialtiesScreen),
        kClinicsPath: find.byType(ClinicsScreen),
        kStatisticsPath: find.byType(StatisticsScreen),
        kNewUserPath: find.byType(NewUserScreen),
        kNewSpecialtyPath: find.byType(NewSpecialtyScreen),
        kNewClinicPath: find.byType(NewClinicScreen),
      };
      for (final entry in screens.entries) {
        await goTo(tester, container, entry.key);
        expect(locationOf(container), entry.key);
        expect(entry.value, findsOneWidget, reason: entry.key);
      }
      expect(find.text('Próximamente'), findsNothing);
    });

    test('la ruta de estadísticas cuelga de la sección del administrador', () {
      final section = UserRole.administrador.sections.firstWhere(
        (s) => s.slug == 'estadisticas',
      );

      expect(kStatisticsPath, '/admin/estadisticas');
      expect(UserRole.administrador.sectionPath(section), kStatisticsPath);
    });

    testWidgets('estadísticas abre su pantalla con las cuatro pestañas y no '
        '"Próximamente"', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.administrador);

      await goTo(tester, container, kStatisticsPath);

      expect(locationOf(container), kStatisticsPath);
      expect(find.byType(StatisticsScreen), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(4));
      expect(find.text('Inasistencias'), findsOneWidget);
      expect(find.text('Próximamente'), findsNothing);
      // Sigue dentro del menú del administrador.
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('estadísticas se abre desde el menú del administrador', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.administrador);

      await tester.tap(find.text('Estadísticas').first);
      await tester.pumpAndSettle();

      expect(locationOf(container), kStatisticsPath);
      expect(find.byType(StatisticsScreen), findsOneWidget);
    });

    testWidgets('socio, funcionario y médico no entran a estadísticas', (
      tester,
    ) async {
      for (final role in [
        UserRole.socio,
        UserRole.funcionario,
        UserRole.medico,
      ]) {
        final container = await pumpApp(tester);
        await _loginAs(tester, container, role);

        await goTo(tester, container, kStatisticsPath);

        expect(locationOf(container), role.homePath, reason: role.name);
        expect(find.byType(StatisticsScreen), findsNothing, reason: role.name);
      }
      await unmountApp(tester);
    });

    testWidgets('sin sesión estadísticas lleva al login', (tester) async {
      final container = await pumpApp(tester);

      await goTo(tester, container, kStatisticsPath);

      expect(locationOf(container), '/login');
      expect(find.byType(StatisticsScreen), findsNothing);
    });

    testWidgets('el alta se abre y se cierra dentro del menú del '
        'administrador', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.administrador);

      await tester.tap(find.text('Especialidades').first);
      await tester.pumpAndSettle();
      expect(locationOf(container), kSpecialtiesPath);

      await tester.tap(find.text('Nueva especialidad'));
      await tester.pumpAndSettle();
      expect(locationOf(container), kNewSpecialtyPath);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(locationOf(container), kSpecialtiesPath);
      expect(find.byType(SpecialtiesScreen), findsOneWidget);
    });

    testWidgets('corregir una especialidad se abre desde su lápiz y vuelve', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.administrador);

      await tester.tap(find.text('Especialidades').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('specialty-edit-2')));
      await tester.pumpAndSettle();

      expect(locationOf(container), '/admin/especialidades/2/corregir');
      expect(find.byType(EditSpecialtyScreen), findsOneWidget);
      expect(find.text('Corregir especialidad'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(locationOf(container), kSpecialtiesPath);
    });

    testWidgets('corregir con un id que no es un número muestra que no se '
        'encontró', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.administrador);

      await goTo(tester, container, '/admin/especialidades/abc/corregir');

      expect(find.byType(EditSpecialtyScreen), findsOneWidget);
      expect(find.text('No encontramos esa especialidad.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las subrutas de alta tampoco se abren sin sesión ni con '
        'otro rol', (tester) async {
      final anonymous = await pumpApp(tester);
      await goTo(tester, anonymous, kNewUserPath);
      expect(locationOf(anonymous), '/login');

      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);
      await goTo(tester, container, kNewClinicPath);
      expect(locationOf(container), UserRole.funcionario.homePath);
      // La home del funcionario ya es la consulta de turnos, con providers
      // `autoDispose` que dejan un timer al desmontar.
      await unmountApp(tester);
    });
  });

  group('área del funcionario: turnos', () {
    const turnosPaths = [
      kShiftsPath,
      kNewWeeklyShiftPath,
      kReinstateShiftsPath,
    ];

    String detail(int id) => weeklyShiftDetailLocation(id);

    test('las rutas cuelgan de la sección "Turnos" del funcionario', () {
      final turnos = UserRole.funcionario.sections.firstWhere(
        (s) => s.slug == 'turnos',
      );
      expect(kShiftsPath, UserRole.funcionario.sectionPath(turnos));
      expect(kShiftsPath, UserRole.funcionario.homePath);
      expect(kNewWeeklyShiftPath, startsWith('$kShiftsPath/'));
      expect(kWeeklyShiftDetailPath, startsWith('$kShiftsPath/'));
      expect(kReinstateShiftsPath, startsWith('$kShiftsPath/'));
    });

    testWidgets('al entrar, el funcionario ve la consulta de turnos y "Turnos" '
        'en el menú', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);

      expect(locationOf(container), kShiftsPath);
      expect(find.byType(ShiftsScreen), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Turnos'), findsWidgets);
      expect(find.text('Próximamente'), findsNothing);
    });

    testWidgets('las cuatro rutas abren su pantalla', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);

      final screens = {
        kShiftsPath: find.byType(ShiftsScreen),
        kNewWeeklyShiftPath: find.byType(NewWeeklyShiftScreen),
        detail(1): find.byType(WeeklyShiftDetailScreen),
        kReinstateShiftsPath: find.byType(ReinstateShiftsScreen),
      };
      for (final entry in screens.entries) {
        await goTo(tester, container, entry.key);
        expect(locationOf(container), entry.key);
        expect(entry.value, findsOneWidget, reason: entry.key);
      }
      await unmountApp(tester);
    });

    testWidgets('"nuevo" y "configuracion/:id" no se pisan', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);

      await goTo(tester, container, kNewWeeklyShiftPath);
      expect(find.byType(NewWeeklyShiftScreen), findsOneWidget);
      expect(find.byType(WeeklyShiftDetailScreen), findsNothing);

      await goTo(tester, container, detail(2));
      expect(find.byType(WeeklyShiftDetailScreen), findsOneWidget);
      expect(find.byType(NewWeeklyShiftScreen), findsNothing);
      final screen = tester.widget<WeeklyShiftDetailScreen>(
        find.byType(WeeklyShiftDetailScreen),
      );
      expect(screen.id, 2);
      await unmountApp(tester);
    });

    testWidgets('un id que no es un número vuelve a la consulta', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);

      for (final bad in ['abc', 'nuevo', '1x', '-']) {
        await goTo(tester, container, '$kShiftsPath/configuracion/$bad');
        expect(locationOf(container), kShiftsPath, reason: bad);
        expect(find.byType(ShiftsScreen), findsOneWidget, reason: bad);
        expect(find.byType(WeeklyShiftDetailScreen), findsNothing);
      }
      await unmountApp(tester);
    });

    testWidgets('"configuracion" sin id no es una página', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);

      await goTo(tester, container, '$kShiftsPath/configuracion');

      expect(find.text('Página no encontrada'), findsOneWidget);
      await unmountApp(tester);
    });

    testWidgets(
      '"Nuevo turno semanal" y "Cancelar" se mueven dentro del menú',
      (tester) async {
        final container = await pumpApp(tester);
        await _loginAs(tester, container, UserRole.funcionario);

        await tester.tap(find.text('Nuevo turno semanal'));
        await tester.pumpAndSettle();
        expect(locationOf(container), kNewWeeklyShiftPath);
        expect(find.byType(NewWeeklyShiftScreen), findsOneWidget);
        expect(find.byType(NavigationRail), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(locationOf(container), kShiftsPath);
        expect(find.byType(ShiftsScreen), findsOneWidget);
        await unmountApp(tester);
      },
    );

    testWidgets('"Volver al listado" del detalle lleva a la consulta', (
      tester,
    ) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);
      await goTo(tester, container, detail(1));

      await tester.tap(find.text('Volver al listado'));
      await tester.pumpAndSettle();

      expect(locationOf(container), kShiftsPath);
      expect(find.byType(ShiftsScreen), findsOneWidget);
      // Al volver, la consulta pide la lista. El repositorio falso tarda
      // 300 ms, y hay que dejarlo terminar antes de cerrar la pantalla.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await unmountApp(tester);
    });

    testWidgets('socio, médico y administrador no entran a ninguna de las '
        'cuatro rutas', (tester) async {
      for (final role in [
        UserRole.socio,
        UserRole.medico,
        UserRole.administrador,
      ]) {
        final container = await pumpApp(tester);
        await _loginAs(tester, container, role);
        for (final path in [...turnosPaths, detail(1)]) {
          await goTo(tester, container, path);
          expect(
            locationOf(container),
            role.homePath,
            reason: '${role.name} → $path',
          );
        }
      }
      await unmountApp(tester);
    });

    testWidgets('sin sesión las cuatro rutas llevan al login', (tester) async {
      final container = await pumpApp(tester);

      for (final path in [...turnosPaths, detail(1)]) {
        await goTo(tester, container, path);
        expect(locationOf(container), '/login', reason: path);
      }
    });
  });

  testWidgets('sin sesión, una ruta de un rol lleva al login', (tester) async {
    final container = await pumpApp(tester);

    await goTo(tester, container, '/admin/usuarios');

    expect(locationOf(container), '/login');
  });

  testWidgets('al cerrar la sesión se vuelve al login', (tester) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.socio);

    container.read(sessionProvider.notifier).clear();
    await tester.pumpAndSettle();

    expect(locationOf(container), '/login');
    await unmountApp(tester);
  });

  testWidgets('una sesión caída lleva al login con un aviso comprensible', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.funcionario);

    container.read(sessionProvider.notifier).clear(expired: true);
    await tester.pumpAndSettle();

    expect(locationOf(container), '/login');
    expect(find.text('Tu sesión se cerró'), findsOneWidget);
    expect(
      find.textContaining('comunicate con la institución'),
      findsOneWidget,
    );
  });

  group('redirectFor en Mi cuenta (/cuenta)', () {
    final uri = Uri.parse('/cuenta');

    test('sin sesión va al login', () {
      expect(redirectFor(const SessionState(), uri), '/login');
    });

    test('mientras se verifica la sesión va a la raíz', () {
      expect(
        redirectFor(const SessionState(status: SessionStatus.checking), uri),
        '/',
      );
    });

    test('con sesión de cada uno de los cuatro roles se queda', () {
      for (final role in UserRole.values) {
        final session = SessionState(
          status: SessionStatus.authenticated,
          accessToken: 't',
          role: role,
        );
        expect(redirectFor(session, uri), null, reason: role.name);
      }
    });
  });
}
