import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'la pantalla de llegada cuelga de la sección "Llegada" del funcionario',
    () {
      final section = UserRole.funcionario.sections.firstWhere(
        (s) => s.slug == 'llegada',
      );

      expect(kArrivalPath, '/funcionario/llegada');
      expect(UserRole.funcionario.sectionPath(section), kArrivalPath);
    },
  );
}
