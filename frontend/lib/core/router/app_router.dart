import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agenda/screens/appointments_pending_screen.dart';
import '../../features/agenda/screens/appointment_detail_screen.dart';
import '../../features/agenda/screens/availability_screen.dart';
import '../../features/auth/models/access_type.dart';
import '../../features/auth/models/user_role.dart';
import '../../features/auth/providers/session_provider.dart';
import '../../features/auth/screens/first_login_activation_screen.dart';
import '../../features/auth/screens/first_login_request_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/consultorios/screens/clinics_screen.dart';
import '../../features/consultorios/screens/new_clinic_screen.dart';
import '../../features/medico/screens/doctor_appointment_result_screen.dart';
import '../../features/medico/screens/doctor_result_routes.dart';
import '../../features/medico/screens/doctor_shifts_screen.dart';
import '../../features/especialidades/screens/new_specialty_screen.dart';
import '../../features/especialidades/screens/specialties_screen.dart';
import '../../features/turnos/screens/new_weekly_shift_screen.dart';
import '../../features/turnos/screens/shift_routes.dart';
import '../../features/turnos/screens/shifts_screen.dart';
import '../../features/turnos/screens/weekly_shift_detail_screen.dart';
import '../../features/usuarios/screens/new_user_screen.dart';
import '../../features/usuarios/screens/user_routes.dart';
import '../../features/usuarios/screens/users_screen.dart';
import '../widgets/coming_soon_screen.dart';
import 'app_sections.dart';
import 'app_shell.dart';

const String kLoginPath = '/login';
const String kFirstLoginPath = '/primer-ingreso';
const String kFirstLoginRequestPath = '/primer-ingreso/solicitar';

bool _isFirstLoginPath(String path) =>
    path == kFirstLoginPath || path == kFirstLoginRequestPath;

const String kDoctorShiftsPath = '/medico/turnos';

/// A dónde redirigir según la sesión y la ruta pedida, o `null` si se puede
/// entrar. Es el guard del router: solo comodidad de navegación, la
/// autorización real es del servidor.
///
/// - Verificando la sesión: todo va a la pantalla de carga, salvo el
///   primer ingreso, para no perder el `token` del enlace del correo.
/// - Sin sesión: solo `/login` y el primer ingreso; todo lo demás va a login.
/// - Con sesión: las pantallas de acceso y la raíz van a la home del rol, y
///   las rutas de otro rol también.
String? redirectFor(SessionState session, Uri uri) {
  final path = uri.path;
  switch (session.status) {
    case SessionStatus.checking:
      return path == '/' || _isFirstLoginPath(path) ? null : '/';
    case SessionStatus.unauthenticated:
      if (path == kFirstLoginPath &&
          (uri.queryParameters['token'] ?? '').isEmpty) {
        return kFirstLoginRequestPath;
      }
      return path == kLoginPath || _isFirstLoginPath(path) ? null : kLoginPath;
    case SessionStatus.authenticated:
      final role = session.role!;
      if (path == '/' || path == kLoginPath || _isFirstLoginPath(path)) {
        return role.homePath;
      }
      final owner = UserRole.fromPath(path);
      if (owner != null && (owner != role || path == owner.routePrefix)) {
        return role.homePath;
      }
      return null;
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _SessionRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) =>
        redirectFor(ref.read(sessionProvider), state.uri),
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: kLoginPath,
        builder: (context, state) => LoginScreen(
          access: AccessType.fromQuery(state.uri.queryParameters['acceso']),
          accountActivated: state.uri.queryParameters['activada'] == '1',
        ),
      ),
      GoRoute(
        path: kFirstLoginPath,
        builder: (context, state) => FirstLoginActivationScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
        routes: [
          GoRoute(
            path: 'solicitar',
            builder: (context, state) => FirstLoginRequestScreen(
              access: AccessType.fromQuery(state.uri.queryParameters['acceso']),
            ),
          ),
        ],
      ),
      // El guard de `redirectFor` deja entrar solo al médico: el prefijo
      // `/medico` es de ese rol.
      GoRoute(
        path: kDoctorResultPath,
        // Un id que no es un número vuelve a "Mis turnos".
        redirect: (context, state) =>
            _appointmentId(state) == null ? kDoctorShiftsPath : null,
        builder: (context, state) => DoctorAppointmentResultScreen(
          appointmentId: _appointmentId(state)!,
          patientName: state.uri.queryParameters['paciente'],
        ),
      ),
      for (final role in UserRole.values) _roleShell(role),
    ],
  );
});

/// El shell de un rol: una rama por sección. Las que todavía no tienen
/// pantalla muestran "Próximamente".
RouteBase _roleShell(UserRole role) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell, sections: role.sections),
    branches: [
      for (final section in role.sections)
        StatefulShellBranch(routes: [_sectionRoute(role, section)]),
    ],
  );
}

/// La ruta de una sección. Las del administrador (usuarios, especialidades y
/// consultorios) y la de turnos del funcionario tienen su pantalla y sus
/// subrutas; el resto muestra "Próximamente".
GoRoute _sectionRoute(UserRole role, AppSection section) {
  final path = role.sectionPath(section);
  if (role == UserRole.funcionario && path == kShiftsPath) {
    return GoRoute(
      path: path,
      builder: (context, state) => const ShiftsScreen(),
      routes: [
        // `nuevo` (un segmento) y `configuracion/:id` (dos) no se pisan.
        GoRoute(
          path: 'nuevo',
          builder: (context, state) => const NewWeeklyShiftScreen(),
        ),
        GoRoute(
          path: 'configuracion/:id',
          // Un id que no es un número no abre el detalle: vuelve al listado.
          redirect: (context, state) =>
              _weeklyShiftId(state) == null ? kShiftsPath : null,
          builder: (context, state) =>
              WeeklyShiftDetailScreen(id: _weeklyShiftId(state)!),
        ),
      ],
    );
  }
  if (role == UserRole.administrador) {
    switch (path) {
      case kUsersPath:
        return GoRoute(
          path: path,
          builder: (context, state) => const UsersScreen(),
          routes: [
            GoRoute(
              path: 'nuevo',
              builder: (context, state) => const NewUserScreen(),
            ),
          ],
        );
      case kSpecialtiesPath:
        return GoRoute(
          path: path,
          builder: (context, state) => const SpecialtiesScreen(),
          routes: [
            GoRoute(
              path: 'nueva',
              builder: (context, state) => const NewSpecialtyScreen(),
            ),
          ],
        );
      case kClinicsPath:
        return GoRoute(
          path: path,
          builder: (context, state) => const ClinicsScreen(),
          routes: [
            GoRoute(
              path: 'nuevo',
              builder: (context, state) => const NewClinicScreen(),
            ),
          ],
        );
    }
  }
  if (role == UserRole.medico && path == kDoctorShiftsPath) {
    return GoRoute(
      path: path,
      builder: (context, state) => const DoctorShiftsScreen(),
    );
  }
  if (role == UserRole.socio) {
    switch (path) {
      case kAvailabilityPath:
        return GoRoute(
          path: path,
          builder: (context, state) => const AvailabilityScreen(),
        );
      case kAppointmentsPath:
        return GoRoute(
          path: path,
          builder: (context, state) => const AppointmentsPendingScreen(),
          routes: [
            GoRoute(
              path: ':id',
              redirect: (context, state) =>
                  _appointmentId(state) == null ? kAppointmentsPath : null,
              builder: (context, state) =>
                  AppointmentDetailScreen(id: _appointmentId(state)!),
            ),
          ],
        );
    }
  }
  return GoRoute(
    path: path,
    builder: (context, state) => ComingSoonScreen(title: section.label),
  );
}

/// El `:id` de la ruta del detalle de un turno semanal, o `null` si no son
/// solo dígitos (o no entra en un entero).
int? _weeklyShiftId(GoRouterState state) {
  final text = state.pathParameters['id'] ?? '';
  return RegExp(r'^\d+$').hasMatch(text) ? int.tryParse(text) : null;
}

int? _appointmentId(GoRouterState state) {
  final text = state.pathParameters['id'] ?? '';
  final id = RegExp(r'^\d+$').hasMatch(text) ? int.tryParse(text) : null;
  return id != null && id > 0 ? id : null;
}

/// Puente entre sessionProvider y GoRouter: cada cambio de sesión notifica a
/// GoRouter para que vuelva a correr `redirect` sobre la ubicación actual.
/// Sin esto, `redirect` sigue siendo correcto pero nunca se re-evalúa solo,
/// así que la navegación no reacciona a login/logout/expiración hasta la
/// próxima navegación manual.
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

class _NotFoundScreen extends ConsumerWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider).role;
    return Scaffold(
      appBar: AppBar(title: const Text('Página no encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No encontramos la página que buscás. Volvé al inicio y '
                'elegí una sección del menú.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(role?.homePath ?? kLoginPath),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
