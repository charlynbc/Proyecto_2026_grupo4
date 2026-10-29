import 'package:agenda_medica/features/turnos/models/doctor_shift.dart';
import 'package:agenda_medica/features/turnos/providers/doctor_shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/doctor_shifts_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_doctor_shift_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith(
          (ref) async => FakeDoctorShiftRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('devuelve los turnos del médico para la fecha pedida', () async {
    final date = DateTime(2026, 10, 28);

    final shifts = await container.read(doctorShiftsProvider(date).future);

    expect(shifts, isA<List<DoctorShift>>());
    expect(shifts, isNotEmpty);
    expect(shifts.first.fecha, date);
    expect(shifts.map((shift) => shift.estado), containsAll(['ACTIVO', 'SUSPENDIDO']));
  });
}
