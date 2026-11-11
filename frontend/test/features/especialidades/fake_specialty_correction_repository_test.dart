import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_correction_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_correction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Semilla de FakeAdminDatabase: 1 Medicina General (sin pase), 2 Cardiología
// (con pase), 3 Dermatología (con pase).

(FakeAdminDatabase, FakeSpecialtyCorrectionRepository) _fake() {
  final db = FakeAdminDatabase();
  return (db, FakeSpecialtyCorrectionRepository(db, latency: Duration.zero));
}

Specialty _byId(FakeAdminDatabase db, int id) =>
    db.specialties.singleWhere((s) => s.id == id);

Matcher _failure(SpecialtyCorrectionFailure failure, String message) =>
    isA<SpecialtyCorrectionException>()
        .having((e) => e.failure, 'failure', failure)
        .having((e) => e.message, 'message', message);

void main() {
  test('renombrar Medicina General a "Medicina Familiar" lo guarda', () async {
    final (db, fake) = _fake();

    final result = await fake.correct(1, name: 'Medicina Familiar');

    expect(result.id, 1);
    expect(result.name, 'Medicina Familiar');
    expect(result.requiresReferral, isFalse);
    expect(_byId(db, 1).name, 'Medicina Familiar');
    expect(db.specialties, hasLength(3));
  });

  test('el nombre se guarda recortado', () async {
    final (db, fake) = _fake();

    await fake.correct(1, name: '  Medicina Familiar  ');

    expect(_byId(db, 1).name, 'Medicina Familiar');
  });

  test('renombrar Cardiología como otra existente es duplicada', () async {
    final (db, fake) = _fake();

    await expectLater(
      fake.correct(2, name: 'DERMATOLOGÍA'),
      throwsA(
        _failure(
          SpecialtyCorrectionFailure.duplicate,
          'Ya existe una especialidad registrada con ese nombre.',
        ),
      ),
    );
    expect(_byId(db, 2).name, 'Cardiología');
  });

  test('cambiar solo mayúsculas y tildes de la misma se guarda', () async {
    final (db, fake) = _fake();

    final result = await fake.correct(2, name: 'CARDIOLOGÍA');

    expect(result.name, 'CARDIOLOGÍA');
    expect(_byId(db, 2).name, 'CARDIOLOGÍA');
  });

  test('cambiar solo el pase deja el nombre igual', () async {
    final (db, fake) = _fake();

    final result = await fake.correct(2, requiresReferral: false);

    expect(result.name, 'Cardiología');
    expect(result.requiresReferral, isFalse);
    expect(_byId(db, 2).name, 'Cardiología');
    expect(_byId(db, 2).requiresReferral, isFalse);
  });

  test('cambiar solo el nombre deja el pase igual', () async {
    final (db, fake) = _fake();

    await fake.correct(2, name: 'Cardiología clínica');

    expect(_byId(db, 2).requiresReferral, isTrue);
  });

  test('el id 9999 es no encontrada', () async {
    final (_, fake) = _fake();

    await expectLater(
      fake.correct(9999, name: 'Otra'),
      throwsA(
        _failure(
          SpecialtyCorrectionFailure.notFound,
          'No se encontró la especialidad.',
        ),
      ),
    );
  });

  test('un nombre de 121 caracteres es validación', () async {
    final (db, fake) = _fake();

    await expectLater(
      fake.correct(1, name: 'a' * 121),
      throwsA(
        _failure(
          SpecialtyCorrectionFailure.validation,
          'El nombre supera 120 caracteres',
        ),
      ),
    );
    expect(_byId(db, 1).name, 'Medicina General');
  });

  test('un nombre de 120 caracteres se guarda', () async {
    final (db, fake) = _fake();

    await fake.correct(1, name: 'a' * 120);

    expect(_byId(db, 1).name, 'a' * 120);
  });

  test('un nombre vacío o de espacios es validación', () async {
    final (db, fake) = _fake();

    for (final name in ['', '   ']) {
      await expectLater(
        fake.correct(1, name: name),
        throwsA(
          _failure(
            SpecialtyCorrectionFailure.validation,
            'El nombre es obligatorio',
          ),
        ),
      );
    }
    expect(_byId(db, 1).name, 'Medicina General');
  });

  test('primero se revisa que exista y después el nombre', () async {
    final (_, fake) = _fake();

    await expectLater(
      fake.correct(9999, name: ''),
      throwsA(
        isA<SpecialtyCorrectionException>().having(
          (e) => e.failure,
          'failure',
          SpecialtyCorrectionFailure.notFound,
        ),
      ),
    );
  });
}
