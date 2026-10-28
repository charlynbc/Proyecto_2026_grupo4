import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:agenda_medica/features/consultorios/screens/new_clinic_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_appointment_result_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_result_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_shifts_screen.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/especialidades/screens/new_specialty_screen.dart';
import 'package:agenda_medica/features/especialidades/screens/specialties_screen.dart';
import 'package:agenda_medica/features/turnos/screens/new_weekly_shift_screen.dart';
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
    'el médico, con una sola sección, no muestra barra de navegación',
    (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(DoctorShiftsScreen), findsOneWidget);
      await unmountApp(tester);
      container.invalidate(doctorAgendaControllerProvider);
    },
  );

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

  group('área del administrador', () {
    testWidgets('cada sección abre su pantalla y estadísticas sigue en '
        '"Próximamente"', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.administrador);
      expect(find.byType(UsersScreen), findsOneWidget);

      final screens = {
        kUsersPath: find.byType(UsersScreen),
        kSpecialtiesPath: find.byType(SpecialtiesScreen),
        kClinicsPath: find.byType(ClinicsScreen),
        kNewUserPath: find.byType(NewUserScreen),
        kNewSpecialtyPath: find.byType(NewSpecialtyScreen),
        kNewClinicPath: find.byType(NewClinicScreen),
      };
      for (final entry in screens.entries) {
        await goTo(tester, container, entry.key);
        expect(locationOf(container), entry.key);
        expect(entry.value, findsOneWidget, reason: entry.key);
      }

      await goTo(tester, container, '/admin/estadisticas');
      expect(locationOf(container), '/admin/estadisticas');
      expect(find.text('Próximamente'), findsOneWidget);
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
    const turnosPaths = [kShiftsPath, kNewWeeklyShiftPath];

    String detail(int id) => weeklyShiftDetailLocation(id);

    test('las rutas cuelgan de la sección "Turnos" del funcionario', () {
      final turnos = UserRole.funcionario.sections.firstWhere(
        (s) => s.slug == 'turnos',
      );
      expect(kShiftsPath, UserRole.funcionario.sectionPath(turnos));
      expect(kShiftsPath, UserRole.funcionario.homePath);
      expect(kNewWeeklyShiftPath, startsWith('$kShiftsPath/'));
      expect(kWeeklyShiftDetailPath, startsWith('$kShiftsPath/'));
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

    testWidgets('las tres rutas abren su pantalla', (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);

      final screens = {
        kShiftsPath: find.byType(ShiftsScreen),
        kNewWeeklyShiftPath: find.byType(NewWeeklyShiftScreen),
        detail(1): find.byType(WeeklyShiftDetailScreen),
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
      await unmountApp(tester);
    });

    testWidgets('socio, médico y administrador no entran a ninguna de las '
        'tres rutas', (tester) async {
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

    testWidgets('sin sesión las tres rutas llevan al login', (tester) async {
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
}
