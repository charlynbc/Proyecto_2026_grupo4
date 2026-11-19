import 'package:agenda_medica/core/widgets/bottom_system_inset.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:agenda_medica/features/cuenta/screens/account_screen.dart';
import 'package:agenda_medica/features/cuenta/screens/change_password_screen.dart';
import 'package:agenda_medica/features/cuenta/screens/edit_account_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_appointment_result_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_attention_detail_screen.dart';
import 'package:agenda_medica/features/medico/screens/doctor_patient_history_screen.dart';
import 'package:agenda_medica/features/novedades/screens/announcement_validity_screen.dart';
import 'package:agenda_medica/features/novedades/screens/carousel_selection_screen.dart';
import 'package:agenda_medica/features/novedades/screens/edit_announcement_screen.dart';
import 'package:agenda_medica/features/novedades/screens/new_announcement_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/system_inset_support.dart';

/// Las diez rutas de nivel superior (fuera de `AppShell`) no tienen barra
/// inferior propia: cada una tiene que quedar dentro de un `BottomSystemInset`.
void main() {
  final cases = <(String, UserRole, String, Type)>[
    ('Mi cuenta', UserRole.socio, kAccountPath, AccountScreen),
    ('Editar mis datos', UserRole.socio, kAccountEditPath, EditAccountScreen),
    (
      'Cambiar contraseña',
      UserRole.socio,
      kAccountPasswordPath,
      ChangePasswordScreen,
    ),
    (
      'Resultado de la consulta (médico)',
      UserRole.medico,
      '/medico/consultas/1/resultado',
      DoctorAppointmentResultScreen,
    ),
    (
      'Historia del paciente (médico)',
      UserRole.medico,
      '/medico/pacientes/1/historia',
      DoctorPatientHistoryScreen,
    ),
    (
      'Detalle de la atención (médico)',
      UserRole.medico,
      '/medico/atenciones/1',
      DoctorAttentionDetailScreen,
    ),
    (
      'Nueva novedad (administrador)',
      UserRole.administrador,
      '/admin/cartelera/nueva',
      NewAnnouncementScreen,
    ),
    (
      'Carrusel del Inicio (administrador)',
      UserRole.administrador,
      '/admin/cartelera/carrusel',
      CarouselSelectionScreen,
    ),
    (
      'Vigencia de una novedad (administrador)',
      UserRole.administrador,
      '/admin/cartelera/1/vigencia',
      AnnouncementValidityScreen,
    ),
    (
      'Editar una novedad (administrador)',
      UserRole.administrador,
      '/admin/cartelera/1/editar',
      EditAnnouncementScreen,
    ),
  ];

  for (final (name, role, path, screen) in cases) {
    testWidgets('$name queda dentro de BottomSystemInset', (tester) async {
      final container = await pumpAsWithInset(
        tester,
        role,
        size: kNarrowPhone,
        bottom: kSystemNavigationBar,
      );

      await goTo(tester, container, path);

      expect(find.byType(screen), findsOneWidget, reason: path);
      expect(
        find.ancestor(
          of: find.byType(screen),
          matching: find.byType(BottomSystemInset),
        ),
        findsOneWidget,
        reason: path,
      );
      await unmountApp(tester);
    });
  }
}
