import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/features/medico/models/doctor_shift.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/medico/providers/doctor_cancellation_repository_provider.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_cancellation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('con fakes, cancelar la 11 libera el número en la agenda', () async {
    var dioCalls = 0;
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(true),
        dioProvider.overrideWith((ref) async {
          dioCalls++;
          throw StateError('El modo falso no debe inicializar Dio.');
        }),
      ],
    );
    addTearDown(container.dispose);

    final shifts = await container.read(doctorShiftRepositoryProvider.future);
    final cancel = await container.read(
      doctorCancellationRepositoryProvider.future,
    );

    expect(cancel, isA<FakeDoctorCancellationRepository>());
    await cancel.cancelAppointment(11, 'Imprevisto de guardia');

    final numbers = await shifts.listNumbers(1);
    expect(numbers.items[0].appointmentId, 10);
    expect(
      numbers.items[1],
      const DoctorShiftNumber(
        numberId: 2,
        number: 2,
        startTime: '09:20',
        endTime: '09:40',
      ),
    );
    final listed = await shifts.listShifts('2026-10-30');
    expect(listed.single.reservedCount, 1);
    expect(listed.single.numbersCount, 3);
    expect(dioCalls, 0);
  });
}
