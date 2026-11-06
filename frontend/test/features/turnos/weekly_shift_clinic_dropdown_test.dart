import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/turnos/screens/new_weekly_shift_screen.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';

void main() {
  testWidgets('el desplegable de consultorio abre 3, 7 y 12', (tester) async {
    final admin = FakeAdminDatabase();
    await pumpAdminScreens(
      tester,
      size: const Size(900, 1400),
      initialLocation: kNewWeeklyShiftPath,
      routes: [
        GoRoute(
          path: kNewWeeklyShiftPath,
          builder: (_, _) => const NewWeeklyShiftScreen(),
        ),
      ],
      overrides: [
        specialtyRepositoryProvider.overrideWith(
          (ref) async => FakeSpecialtyRepository(admin, latency: Duration.zero),
        ),
        clinicRepositoryProvider.overrideWith(
          (ref) async => FakeClinicRepository(admin, latency: Duration.zero),
        ),
      ],
    );

    await tester.ensureVisible(find.byKey(const Key('field-clinic')));
    await tester.tap(find.byKey(const Key('field-clinic')));
    await tester.pumpAndSettle();

    const names = ['Consultorio 3', 'Consultorio 7', 'Consultorio 12'];
    for (var i = 1; i < names.length; i++) {
      expect(
        tester.getTopLeft(find.text(names[i - 1])).dy,
        lessThan(tester.getTopLeft(find.text(names[i])).dy),
      );
    }
  });
}
