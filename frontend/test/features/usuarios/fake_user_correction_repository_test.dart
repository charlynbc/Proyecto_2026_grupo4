import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/validators/uruguayan_ci_validator.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_correction_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_correction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Las cuentas sembradas, por id: 1 Ana (socio, activada), 2 Bruno (funcionario),
// 3 Bruno (médico, inactiva), 4 Carla (médico, especialidad 1), 5 Diego
// (administrador), 6 Esteban (médico, especialidad 2), 7 Florencia (médico,
// especialidades 1 y 3, sin completar el primer ingreso).

FakeUserCorrectionRepository _repo(FakeAdminDatabase db) =>
    FakeUserCorrectionRepository(db, latency: Duration.zero);

Future<UserCorrectionFailure> _failureOf(Future<Object?> call) async {
  try {
    await call;
  } on UserCorrectionException catch (e) {
    return e.failure;
  }
  throw StateError('Se esperaba un UserCorrectionException');
}

/// Una cédula libre y válida; el dígito verificador es un dato de entrada.
String _freeCi() {
  const body = '3644426';
  return '$body${calculateUruguayanCiVerifierDigit(body)}';
}

void main() {
  group('fetch', () {
    test('devuelve el detalle de Carla con sus datos sembrados', () async {
      final detail = await _repo(FakeAdminDatabase()).fetch(4);

      expect(detail.id, 4);
      expect(detail.ci, '34567894');
      expect(detail.firstName, 'Carla');
      expect(detail.lastName, 'Méndez');
      expect(detail.birthDate, DateTime.utc(1978, 11, 11));
      expect(detail.role, UserRole.medico);
      expect(detail.email, 'carla.mendez@example.org');
      expect(detail.phone1, '094555777');
      expect(detail.phone2, isNull);
      expect(detail.address, 'Calle Mercedes 870');
      expect(detail.specialtyIds, [1]);
      expect(detail.status, AccountStatus.active);
      expect(detail.activated, isTrue);
    });

    test(
      'una cuenta inactiva y una sin primer ingreso también se leen',
      () async {
        final repo = _repo(FakeAdminDatabase());

        expect((await repo.fetch(3)).status, AccountStatus.inactive);
        expect((await repo.fetch(7)).activated, isFalse);
        expect((await repo.fetch(1)).specialtyIds, isEmpty);
      },
    );

    test('un id que no existe es notFound', () async {
      expect(
        await _failureOf(_repo(FakeAdminDatabase()).fetch(999)),
        UserCorrectionFailure.notFound,
      );
    });
  });

  group('correct: qué se guarda', () {
    test('cambia solo lo que se manda y devuelve la cuenta', () async {
      final db = FakeAdminDatabase();

      final detail = await _repo(db)
          .correct(4, const AccountCorrection(phone1: '091111222'));

      expect(detail.phone1, '091111222');
      expect(detail.address, 'Calle Mercedes 870');
      expect(detail.firstName, 'Carla');
      expect(db.accounts[3].phone1, '091111222');
    });

    test('el correo se guarda en minúsculas', () async {
      final detail = await _repo(FakeAdminDatabase())
          .correct(4, const AccountCorrection(email: 'Carla@Ejemplo.ORG'));

      expect(detail.email, 'carla@ejemplo.org');
    });

    test('el teléfono 2 se agrega y después se borra', () async {
      final db = FakeAdminDatabase();
      final repo = _repo(db);

      final added = await repo.correct(
        4,
        const AccountCorrection(phone2: TextChange.set('099777888')),
      );
      expect(added.phone2, '099777888');

      final cleared = await repo.correct(
        4,
        const AccountCorrection(phone2: TextChange.clear()),
      );
      expect(cleared.phone2, isNull);
      expect(cleared.phone1, '094555777');
    });

    test(
      'la dirección de una cuenta sin primer ingreso se puede borrar',
      () async {
        final detail = await _repo(FakeAdminDatabase())
            .correct(7, const AccountCorrection(address: TextChange.clear()));

        expect(detail.address, isNull);
      },
    );

    test('la dirección de una cuenta activada se puede cambiar', () async {
      final detail = await _repo(FakeAdminDatabase()).correct(
        1,
        const AccountCorrection(address: TextChange.set('Calle Nueva 45')),
      );

      expect(detail.address, 'Calle Nueva 45');
    });
  });

  group('correct: reglas del servidor', () {
    test('sin cambios es validación', () async {
      expect(
        await _failureOf(
          _repo(FakeAdminDatabase()).correct(4, const AccountCorrection()),
        ),
        UserCorrectionFailure.validation,
      );
    });

    test('una cuenta que no existe es notFound', () async {
      expect(
        await _failureOf(
          _repo(FakeAdminDatabase())
              .correct(999, const AccountCorrection(phone1: '091111222')),
        ),
        UserCorrectionFailure.notFound,
      );
    });

    test(
      'nombre vacío, de 101 caracteres o teléfono 1 vacío son validación',
      () async {
        final repo = _repo(FakeAdminDatabase());
        for (final change in [
          const AccountCorrection(firstName: ''),
          AccountCorrection(lastName: 'a' * 101),
          const AccountCorrection(phone1: ''),
          AccountCorrection(phone1: '0' * 31),
          AccountCorrection(phone2: TextChange.set('0' * 31)),
          const AccountCorrection(email: 'sin-arroba'),
        ]) {
          expect(
            await _failureOf(repo.correct(4, change)),
            UserCorrectionFailure.validation,
          );
        }
      },
    );

    test('el nombre de 100 caracteres es válido', () async {
      final detail = await _repo(FakeAdminDatabase())
          .correct(4, AccountCorrection(firstName: 'a' * 100));

      expect(detail.firstName.length, 100);
    });

    test('vaciar la dirección de una cuenta activada es validación', () async {
      expect(
        await _failureOf(
          _repo(FakeAdminDatabase())
              .correct(1, const AccountCorrection(address: TextChange.clear())),
        ),
        UserCorrectionFailure.validation,
      );
    });
  });

  group('correct: CI', () {
    test('con dígito verificador incorrecto es invalidCi', () async {
      final error = await _repo(FakeAdminDatabase())
          .correct(1, const AccountCorrection(ci: '12345673'))
          .then<UserCorrectionException?>((_) => null)
          .onError<UserCorrectionException>((e, _) => e);

      expect(error?.failure, UserCorrectionFailure.invalidCi);
      expect(
        error?.message,
        'La cédula no es válida. Revisá el dígito verificador.',
      );
    });

    test('la CI de otra persona es ciInUse', () async {
      final error = await _repo(FakeAdminDatabase())
          .correct(1, const AccountCorrection(ci: '45678905'))
          .then<UserCorrectionException?>((_) => null)
          .onError<UserCorrectionException>((e, _) => e);

      expect(error?.failure, UserCorrectionFailure.ciInUse);
      expect(error?.message, 'Esa cédula ya pertenece a otra persona.');
    });

    test('una CI libre y válida se guarda, con puntos y guion', () async {
      final ci = _freeCi();
      final dotted =
          '${ci.substring(0, 1)}.${ci.substring(1, 4)}.${ci.substring(4, 7)}-${ci.substring(7)}';

      final detail = await _repo(FakeAdminDatabase())
          .correct(1, AccountCorrection(ci: dotted));

      expect(detail.ci, ci);
    });

    test('la CI, el nombre y el apellido valen para todas las cuentas de la persona', () async {
      final db = FakeAdminDatabase();
      final ci = _freeCi();

      await _repo(db).correct(
        2,
        AccountCorrection(
          ci: ci,
          firstName: 'Bruno Andrés',
          lastName: 'Pereyra',
          email: 'bruno.nuevo@example.org',
        ),
      );

      final other = db.accounts.firstWhere((a) => a.id == 3);
      expect(other.ci, ci);
      expect(other.firstName, 'Bruno Andrés');
      expect(other.lastName, 'Pereyra');
      expect(other.email, 'bruno.pereira@example.org');
      expect(
        db.accounts.firstWhere((a) => a.id == 2).email,
        'bruno.nuevo@example.org',
      );
    });

    test('dejar la misma CI no es un conflicto', () async {
      final detail = await _repo(FakeAdminDatabase())
          .correct(1, const AccountCorrection(ci: '1.234.567-2'));

      expect(detail.ci, '12345672');
    });
  });

  group('correct: especialidades', () {
    test('en una cuenta que no es médica es validación', () async {
      expect(
        await _failureOf(
          _repo(FakeAdminDatabase())
              .correct(1, const AccountCorrection(specialtyIds: [1])),
        ),
        UserCorrectionFailure.validation,
      );
    });

    test('vacías, repetidas o inexistentes son validación', () async {
      final repo = _repo(FakeAdminDatabase());
      for (final ids in [
        <int>[],
        [1, 1],
        [99],
      ]) {
        expect(
          await _failureOf(
            repo.correct(7, AccountCorrection(specialtyIds: ids)),
          ),
          UserCorrectionFailure.validation,
          reason: '$ids',
        );
      }
    });

    test('reemplazan el conjunto completo del médico', () async {
      final detail = await _repo(FakeAdminDatabase())
          .correct(7, const AccountCorrection(specialtyIds: [2]));

      expect(detail.specialtyIds, [2]);
    });

    test('quitar una especialidad en uso es specialtyInUse', () async {
      final error = await _repo(FakeAdminDatabase())
          .correct(4, const AccountCorrection(specialtyIds: [2]))
          .then<UserCorrectionException?>((_) => null)
          .onError<UserCorrectionException>((e, _) => e);

      expect(error?.failure, UserCorrectionFailure.specialtyInUse);
      expect(
        error?.message,
        'No se puede quitar una especialidad con turnos vigentes o consultas '
        'agendadas.',
      );
    });

    test('agregar una sin quitar la que está en uso es válido', () async {
      final detail = await _repo(FakeAdminDatabase())
          .correct(4, const AccountCorrection(specialtyIds: [1, 2]));

      expect(detail.specialtyIds, [1, 2]);
    });
  });
}
