import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/new_user.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/models/user_filters.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';

NewUser _user({
  String ci = '31415921',
  String firstName = 'Marta',
  String lastName = 'Rodríguez',
  DateTime? birthDate,
  UserRole role = UserRole.funcionario,
  List<int> specialtyIds = const [],
}) => NewUser(
  ci: ci,
  firstName: firstName,
  lastName: lastName,
  birthDate: birthDate ?? DateTime(1978, 3, 15),
  email: 'marta@example.org',
  phone1: '099111222',
  role: role,
  specialtyIds: specialtyIds,
);

void main() {
  late FakeAdminDatabase db;
  late FakeUserRepository repository;

  setUp(() {
    db = FakeAdminDatabase();
    repository = FakeUserRepository(db, latency: Duration.zero);
  });

  group('alta', () {
    test('una CI con dígito verificador malo se rechaza', () {
      expect(
        repository.createUser(_user(ci: '12345670')),
        throwsA(isA<InvalidCiException>()),
      );
    });

    test('la cuenta nueva queda habilitada y sin activar', () async {
      await repository.createUser(_user(ci: '31415921'));

      final page = await repository.listUsers(const UserFilters(query: '3141'));
      expect(page.total, 1);
      expect(page.items.single.status, AccountStatus.active);
      expect(page.items.single.activated, isFalse);
    });

    test('una segunda cuenta de socio para la misma CI se rechaza', () {
      // Ana Rodríguez ya es socia.
      expect(
        repository.createUser(
          _user(
            ci: '12345672',
            firstName: 'Ana',
            lastName: 'Rodríguez',
            birthDate: db.accounts.first.birthDate,
            role: UserRole.socio,
          ),
        ),
        throwsA(isA<DuplicateMemberException>()),
      );
    });

    test('una CI existente con otro nombre o fecha se rechaza', () {
      final known = db.accounts.first;
      expect(
        repository.createUser(
          _user(
            ci: known.ci,
            firstName: 'Anita',
            lastName: known.lastName,
            birthDate: known.birthDate,
            role: UserRole.funcionario,
          ),
        ),
        throwsA(isA<MismatchedPersonDataException>()),
      );
      expect(
        repository.createUser(
          _user(
            ci: known.ci,
            firstName: known.firstName,
            lastName: known.lastName,
            birthDate: DateTime(1999, 1, 1),
            role: UserRole.funcionario,
          ),
        ),
        throwsA(isA<MismatchedPersonDataException>()),
      );
    });

    test('un empleado habilitado impide otra cuenta de empleado', () {
      final bruno = db.accounts.firstWhere(
        (a) => a.role == UserRole.funcionario,
      );
      expect(
        repository.createUser(
          _user(
            ci: bruno.ci,
            firstName: bruno.firstName,
            lastName: bruno.lastName,
            birthDate: bruno.birthDate,
            role: UserRole.administrador,
          ),
        ),
        throwsA(isA<DuplicateStaffException>()),
      );
    });

    test('con la cuenta de empleado inactivada se permite una nueva', () async {
      final bruno = db.accounts.firstWhere(
        (a) => a.role == UserRole.funcionario,
      );
      final index = db.accounts.indexOf(bruno);
      db.accounts[index] = FakeAccount(
        id: bruno.id,
        ci: bruno.ci,
        firstName: bruno.firstName,
        lastName: bruno.lastName,
        birthDate: bruno.birthDate,
        email: bruno.email,
        role: bruno.role,
        status: AccountStatus.inactive,
        createdAt: bruno.createdAt,
      );

      await repository.createUser(
        _user(
          ci: bruno.ci,
          firstName: bruno.firstName,
          lastName: bruno.lastName,
          birthDate: bruno.birthDate,
          role: UserRole.administrador,
        ),
      );

      final page = await repository.listUsers(UserFilters(query: bruno.ci));
      // Seed: Funcionario (inactivado acá) + Médico anterior, más el alta.
      expect(page.total, 3);
    });

    test('un socio puede tener además una cuenta de empleado', () async {
      final ana = db.accounts.first;
      await repository.createUser(
        _user(
          ci: ana.ci,
          firstName: ana.firstName,
          lastName: ana.lastName,
          birthDate: ana.birthDate,
          role: UserRole.funcionario,
        ),
      );
    });

    test('un médico necesita especialidades existentes', () async {
      await expectLater(
        repository.createUser(_user(role: UserRole.medico)),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        repository.createUser(
          _user(role: UserRole.medico, specialtyIds: [999]),
        ),
        throwsA(isA<ApiException>()),
      );
      await repository.createUser(
        _user(role: UserRole.medico, specialtyIds: [1, 2]),
      );
    });

    test('otro rol con especialidades se rechaza', () {
      expect(
        repository.createUser(_user(specialtyIds: [1])),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('listado', () {
    test('pagina con el total del servidor', () async {
      final first = await repository.listUsers(const UserFilters());
      expect(first.items, hasLength(20));
      expect(first.total, db.accounts.length);
      expect(first.hasNext, isTrue);

      final second = await repository.listUsers(const UserFilters(page: 1));
      expect(second.items, hasLength(db.accounts.length - 20));
      expect(second.hasNext, isFalse);
    });

    test('filtra por rol y por estado', () async {
      final medics = await repository.listUsers(
        const UserFilters(role: UserRole.medico),
      );
      expect(medics.items.every((a) => a.role == UserRole.medico), isTrue);
      expect(medics.total, 4);

      final inactive = await repository.listUsers(
        const UserFilters(status: AccountStatus.inactive),
      );
      expect(
        inactive.items.every((a) => a.status == AccountStatus.inactive),
        isTrue,
      );
    });

    test('busca por CI o apellido, sin mayúsculas ni tildes', () async {
      final byLastName = await repository.listUsers(
        const UserFilters(query: 'MENDEZ'),
      );
      expect(byLastName.items.single.lastName, 'Méndez');

      final byCi = await repository.listUsers(
        const UserFilters(query: '4567890'),
      );
      expect(byCi.items.single.ci, '45678905');
    });

    test(
      'ordena por apellido y por fecha de alta, en los dos sentidos',
      () async {
        final byName = await repository.listUsers(const UserFilters(size: 100));
        final names = [for (final a in byName.items) a.lastName];
        expect(names.first, 'Acosta');
        expect(names.last, 'Torres');

        final newestFirst = await repository.listUsers(
          const UserFilters(
            order: UserOrder.createdAt,
            ascending: false,
            size: 100,
          ),
        );
        final dates = [for (final a in newestFirst.items) a.createdAt];
        expect(
          dates,
          orderedEquals([...dates]..sort((a, b) => b.compareTo(a))),
        );
      },
    );
  });
}
