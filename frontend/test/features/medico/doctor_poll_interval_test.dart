import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el sondeo de la agenda del médico es de 15 segundos por defecto', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(doctorPollIntervalProvider),
      const Duration(seconds: 15),
    );
  });
}
