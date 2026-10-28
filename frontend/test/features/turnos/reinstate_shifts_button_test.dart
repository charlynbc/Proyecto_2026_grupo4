import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';
import '../../helpers/shift_listing_data.dart';

const String _reinstatePath = '/funcionario/turnos/rehabilitar';

void main() {
  testWidgets('"Rehabilitar fechas" abre la pantalla de rehabilitar', (
    tester,
  ) async {
    final admin = FakeAdminDatabase();
    final shiftDb = buildListingDb(admin);
    final router = await pumpAdminScreens(
      tester,
      size: const Size(1300, 1800),
      initialLocation: kShiftsPath,
      routes: [
        GoRoute(path: kShiftsPath, builder: (_, _) => const ShiftsScreen()),
        GoRoute(
          path: _reinstatePath,
          builder: (_, _) =>
              const Scaffold(body: Text('Rehabilitar fechas de turnos')),
        ),
      ],
      overrides: [
        shiftRepositoryProvider.overrideWith(
          (ref) async => FakeShiftRepository(shiftDb, latency: Duration.zero),
        ),
        specialtyRepositoryProvider.overrideWith(
          (ref) async =>
              FakeSpecialtyRepository(admin, latency: Duration.zero),
        ),
      ],
    );

    await tester.tap(find.text('Rehabilitar fechas'));
    await tester.pumpAndSettle();

    expect(currentLocation(router), _reinstatePath);
    expect(find.text('Rehabilitar fechas de turnos'), findsOneWidget);
  });
}
