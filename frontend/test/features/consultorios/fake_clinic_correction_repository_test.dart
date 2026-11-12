import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_correction_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_correction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAdminDatabase db;
  late FakeClinicCorrectionRepository repository;

  setUp(() {
    db = FakeAdminDatabase();
    repository = FakeClinicCorrectionRepository(db, latency: Duration.zero);
  });

  test('cambiar ubicación actualiza y devuelve el consultorio', () async {
    final corrected = await repository.correct(1, location: ' Planta alta ');

    expect(corrected.id, 1);
    expect(corrected.name, 'Consultorio 3');
    expect(corrected.location, 'Planta alta');
    expect(db.clinics.first, corrected);
  });

  test('nombre repetido de otro consultorio da duplicate', () async {
    await expectLater(
      repository.correct(2, name: 'consultorio 12'),
      throwsA(
        isA<ClinicCorrectionException>()
            .having(
              (error) => error.failure,
              'failure',
              ClinicCorrectionFailure.duplicate,
            )
            .having(
              (error) => error.message,
              'message',
              'Ya existe un consultorio con ese nombre o número.',
            ),
      ),
    );
  });

  test('nombre normalizado del mismo consultorio se permite', () async {
    final corrected = await repository.correct(2, name: 'CONSULTORIO 7');

    expect(corrected.name, 'CONSULTORIO 7');
    expect(db.clinics[1], corrected);
  });

  test('id inexistente da notFound', () async {
    await expectLater(
      repository.correct(9999, name: 'Consultorio 99'),
      throwsA(
        isA<ClinicCorrectionException>()
            .having(
              (error) => error.failure,
              'failure',
              ClinicCorrectionFailure.notFound,
            )
            .having(
              (error) => error.message,
              'message',
              'No se encontró el consultorio.',
            ),
      ),
    );
  });

  test('nombre vacío y de 121 caracteres dan validation', () async {
    for (final (name, message) in [
      ('   ', 'El nombre es obligatorio'),
      (List.filled(121, 'a').join(), 'El nombre supera 120 caracteres'),
    ]) {
      await expectLater(
        repository.correct(1, name: name),
        throwsA(
          isA<ClinicCorrectionException>()
              .having(
                (error) => error.failure,
                'failure',
                ClinicCorrectionFailure.validation,
              )
              .having((error) => error.message, 'message', message),
        ),
      );
    }
  });

  test('ubicación vacía y de 201 caracteres dan validation', () async {
    for (final (location, message) in [
      ('   ', 'La ubicación es obligatoria'),
      (List.filled(201, 'b').join(), 'La ubicación supera 200 caracteres'),
    ]) {
      await expectLater(
        repository.correct(1, location: location),
        throwsA(
          isA<ClinicCorrectionException>()
              .having(
                (error) => error.failure,
                'failure',
                ClinicCorrectionFailure.validation,
              )
              .having((error) => error.message, 'message', message),
        ),
      );
    }
  });

  test(
    'nombre de 120 y ubicación de 200 caracteres se guardan recortados',
    () async {
      final name = List.filled(120, 'a').join();
      final location = List.filled(200, 'b').join();

      final corrected = await repository.correct(
        1,
        name: ' $name ',
        location: ' $location ',
      );

      expect(corrected.name, name);
      expect(corrected.location, location);
    },
  );
}
