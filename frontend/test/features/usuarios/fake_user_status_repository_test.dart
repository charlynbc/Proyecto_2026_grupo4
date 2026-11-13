import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/repositories/fake_account_repository.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_status_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_status_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Semilla de FakeAdminDatabase (ids por orden de alta): 1 Ana SOCIO, 2 Bruno
// FUNCIONARIO activa, 3 Bruno MEDICO inactiva (misma CI), 4 Carla MEDICO,
// 5 Diego ADMINISTRADOR, 6 Esteban MEDICO.

final _now = DateTime.utc(2026, 11, 10, 15);

(FakeAdminDatabase, FakeUserStatusRepository) _fake({
  Set<int>? doctorsWithActiveShifts,
}) {
  final db = FakeAdminDatabase(clock: () => _now);
  return (
    db,
    FakeUserStatusRepository(
      db,
      latency: Duration.zero,
      doctorsWithActiveShifts: doctorsWithActiveShifts,
    ),
  );
}

AccountStatus _statusOf(FakeAdminDatabase db, int id) =>
    db.accounts.singleWhere((a) => a.id == id).status;

Matcher _failure(UserStatusFailure failure, String message) =>
    isA<UserStatusException>()
        .having((e) => e.failure, 'failure', failure)
        .having((e) => e.message, 'message', message);

void main() {
  test('por defecto el conjunto de médicos con turnos tiene solo a Carla', () {
    final (_, fake) = _fake();

    expect(fake.doctorsWithActiveShifts, {4});
  });

  test('Bruno se inactiva y queda INACTIVA en la base', () async {
    final (db, fake) = _fake();

    final change = await fake.deactivate(2);

    expect(_statusOf(db, 2), AccountStatus.inactive);
    expect(change.id, 2);
    expect(change.ci, '23456783');
    expect(change.status, AccountStatus.inactive);
    expect(change.lastDeactivatedAt, _now);
    expect(change.lastDeactivatedBy, 5);
    expect(change.lastReactivatedAt, isNull);
  });

  test('inactivar a Bruno otra vez es "ya inactiva"', () async {
    final (_, fake) = _fake();
    await fake.deactivate(2);

    await expectLater(
      fake.deactivate(2),
      throwsA(
        _failure(
          UserStatusFailure.alreadyInactive,
          'La cuenta ya está inactiva.',
        ),
      ),
    );
  });

  test('reactivar a Bruno lo deja ACTIVA y completa la reactivación', () async {
    final (db, fake) = _fake();
    await fake.deactivate(2);

    final change = await fake.reactivate(2);

    expect(_statusOf(db, 2), AccountStatus.active);
    expect(change.status, AccountStatus.active);
    expect(change.lastDeactivatedAt, _now);
    expect(change.lastReactivatedAt, _now);
    expect(change.lastReactivatedBy, 5);
  });

  test('reactivar una cuenta activa es "ya activa"', () async {
    final (_, fake) = _fake();

    await expectLater(
      fake.reactivate(2),
      throwsA(
        _failure(UserStatusFailure.alreadyActive, 'La cuenta ya está activa.'),
      ),
    );
  });

  test('Carla tiene turnos activos y no se inactiva', () async {
    final (db, fake) = _fake();

    await expectLater(
      fake.deactivate(4),
      throwsA(
        _failure(
          UserStatusFailure.doctorHasShifts,
          'El médico tiene fechas de turnos activas.',
        ),
      ),
    );
    expect(_statusOf(db, 4), AccountStatus.active);
  });

  test('con el conjunto vacío Carla se inactiva', () async {
    final (db, fake) = _fake(doctorsWithActiveShifts: {});

    await fake.deactivate(4);

    expect(_statusOf(db, 4), AccountStatus.inactive);
  });

  test('Esteban, que no está en el conjunto, se inactiva', () async {
    final (db, fake) = _fake();

    await fake.deactivate(6);

    expect(_statusOf(db, 6), AccountStatus.inactive);
  });

  test('el administrador no se inactiva a sí mismo', () async {
    final (db, fake) = _fake();

    await expectLater(
      fake.deactivate(5),
      throwsA(
        _failure(
          UserStatusFailure.ownAccount,
          'No puede inactivar su propia cuenta',
        ),
      ),
    );
    expect(_statusOf(db, 5), AccountStatus.active);
  });

  test('el administrador no se reactiva a sí mismo', () async {
    final (_, fake) = _fake();

    await expectLater(
      fake.reactivate(5),
      throwsA(
        _failure(
          UserStatusFailure.ownAccount,
          'No puede reactivar su propia cuenta',
        ),
      ),
    );
  });

  test('la cuenta del administrador de la sesión falsa es la de Diego', () {
    final (db, _) = _fake();
    final diego = db.accounts.singleWhere((a) => a.ci == '45678905');
    final session = FakeAccountRepository.personFor(UserRole.administrador);

    expect(diego.id, 5);
    expect(diego.role, UserRole.administrador);
    expect(session.id, 5);
    expect(session.ci, '45678905');
  });

  test('una cuenta de socio es validación en las dos acciones', () async {
    final (db, fake) = _fake();
    final matcher = _failure(
      UserStatusFailure.validation,
      'La cuenta no es de un empleado.',
    );

    await expectLater(fake.deactivate(1), throwsA(matcher));
    await expectLater(fake.reactivate(1), throwsA(matcher));
    expect(_statusOf(db, 1), AccountStatus.active);
  });

  test('el id 9999 es no encontrada en las dos acciones', () async {
    final (_, fake) = _fake();
    final matcher = _failure(
      UserStatusFailure.notFound,
      'No se encontró la cuenta.',
    );

    await expectLater(fake.deactivate(9999), throwsA(matcher));
    await expectLater(fake.reactivate(9999), throwsA(matcher));
  });

  test('ya inactiva se revisa antes que los turnos del médico', () async {
    final (_, fake) = _fake(doctorsWithActiveShifts: {3});

    await expectLater(
      fake.deactivate(3),
      throwsA(
        isA<UserStatusException>().having(
          (e) => e.failure,
          'failure',
          UserStatusFailure.alreadyInactive,
        ),
      ),
    );
  });

  test(
    'reactivar a Bruno médico con Bruno funcionario activo es duplicada',
    () async {
      final (db, fake) = _fake();

      await expectLater(
        fake.reactivate(3),
        throwsA(
          _failure(
            UserStatusFailure.duplicateStaff,
            'Ya hay otra cuenta de empleado habilitada con esa CI.',
          ),
        ),
      );
      expect(_statusOf(db, 3), AccountStatus.inactive);
    },
  );

  test(
    'si se inactiva a Bruno funcionario, Bruno médico se reactiva',
    () async {
      final (db, fake) = _fake();
      await fake.deactivate(2);

      final change = await fake.reactivate(3);

      expect(change.id, 3);
      expect(_statusOf(db, 3), AccountStatus.active);
      expect(_statusOf(db, 2), AccountStatus.inactive);
    },
  );

  test(
    'con Bruno médico activo, Bruno funcionario ya no se reactiva',
    () async {
      final (_, fake) = _fake();
      await fake.deactivate(2);
      await fake.reactivate(3);

      await expectLater(
        fake.reactivate(2),
        throwsA(
          isA<UserStatusException>().having(
            (e) => e.failure,
            'failure',
            UserStatusFailure.duplicateStaff,
          ),
        ),
      );
    },
  );

  test('ya activa se revisa antes que la duplicada', () async {
    final (_, fake) = _fake();

    await expectLater(
      fake.reactivate(2),
      throwsA(
        isA<UserStatusException>().having(
          (e) => e.failure,
          'failure',
          UserStatusFailure.alreadyActive,
        ),
      ),
    );
  });
}
