import 'package:agenda_medica/features/turnos/models/doctor_shift_number.dart';
import 'package:agenda_medica/features/turnos/providers/doctor_shift_numbers_provider.dart';
import 'package:agenda_medica/features/turnos/providers/doctor_shift_repository_provider.dart';
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

  test('devuelve los números del turno y conserva el detalle del turno', () async {
    final params = DoctorShiftNumbersParams(shiftId: 101);

    final response = await container.read(doctorShiftNumbersProvider(params).future);

    expect(response, isA<DoctorShiftNumbersResponse>());
    expect(response.turno.id, 101);
    expect(response.items, isNotEmpty);
    expect(response.items.any((item) => item.consulta != null), isTrue);
    expect(response.items.any((item) => item.disponible), isTrue);
  });
}
