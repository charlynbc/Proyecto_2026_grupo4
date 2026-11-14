import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/models/user_role.dart';
import '../../features/consultorios/models/clinic.dart';
import '../../features/especialidades/models/specialty.dart';
import '../../features/usuarios/models/user_account.dart';
import '../validators/uruguayan_ci_validator.dart';

/// El id de la cuenta del administrador de prueba (Diego Fernández, CI
/// 45678905) en [FakeAdminDatabase]: el que tiene en `accounts` y el que
/// devuelve la cuenta de la sesión falsa. Es la única fuente.
const int kFakeAdminAccountId = 5;

/// Una cuenta del padrón falso, con los datos de la persona que el listado no
/// muestra pero el alta necesita para sus reglas (fecha de nacimiento,
/// especialidades).
class FakeAccount {
  FakeAccount({
    required this.id,
    required this.ci,
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.email,
    required this.role,
    this.status = AccountStatus.active,
    this.activated = true,
    required this.createdAt,
    this.specialtyIds = const [],
    this.phone1 = '',
    this.phone2,
    this.address,
  });

  final int id;
  final String ci;
  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String email;
  final UserRole role;
  final AccountStatus status;
  final bool activated;
  final DateTime createdAt;
  final List<int> specialtyIds;

  /// Datos de contacto de la cuenta, que el listado no muestra pero la
  /// corrección de un usuario (RF-38) sí.
  final String phone1;
  final String? phone2;
  final String? address;

  UserAccount toAccount() => UserAccount(
    id: id,
    ci: ci,
    firstName: firstName,
    lastName: lastName,
    role: role,
    email: email,
    status: status,
    activated: activated,
    createdAt: createdAt,
  );
}

/// Estado en memoria del área del administrador, compartido por los
/// repositories falsos: las especialidades que se dan de alta aparecen en el
/// formulario de usuarios, y las cuentas nuevas en el listado. Se pierde al
/// recargar la app.
class FakeAdminDatabase {
  FakeAdminDatabase({DateTime Function()? clock})
    : clock = clock ?? DateTime.now {
    _seed();
  }

  final DateTime Function() clock;

  final List<Specialty> specialties = [];
  final List<Clinic> clinics = [];
  final List<FakeAccount> accounts = [];

  int _nextSpecialtyId = 1;
  int _nextClinicId = 1;
  int _nextAccountId = 1;

  int newSpecialtyId() => _nextSpecialtyId++;
  int newClinicId() => _nextClinicId++;
  int newAccountId() => _nextAccountId++;

  /// Un nombre comparado como lo hace el servidor: sin espacios sobrantes y
  /// sin distinguir mayúsculas.
  static String normalize(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  void _seed() {
    // Las del mockup 6.1.9.
    specialties
      ..add(
        Specialty(
          id: newSpecialtyId(),
          name: 'Medicina General',
          requiresReferral: false,
        ),
      )
      ..add(
        Specialty(
          id: newSpecialtyId(),
          name: 'Cardiología',
          requiresReferral: true,
        ),
      )
      ..add(
        Specialty(
          id: newSpecialtyId(),
          name: 'Dermatología',
          requiresReferral: true,
        ),
      );
    clinics
      ..add(
        Clinic(
          id: newClinicId(),
          name: 'Consultorio 3',
          location: 'Planta baja',
        ),
      )
      ..add(
        Clinic(id: newClinicId(), name: 'Consultorio 7', location: 'Piso 1'),
      )
      ..add(
        Clinic(id: newClinicId(), name: 'Consultorio 12', location: 'Piso 2'),
      );
    _seedAccounts();
  }

  /// Una persona por rol con las cédulas de los datos de prueba, y el resto
  /// generadas con dígito verificador válido: son más de una página para
  /// poder probar la paginación.
  void _seedAccounts() {
    final now = clock().toUtc();
    DateTime daysAgo(int days) => now.subtract(Duration(days: days));

    void add(
      String ci,
      String first,
      String last,
      UserRole role, {
      AccountStatus status = AccountStatus.active,
      bool activated = true,
      int createdDaysAgo = 30,
      int birthYear = 1980,
      List<int> specialtyIds = const [],
      String? phone1,
      String? phone2,
      String? address,
    }) {
      accounts.add(
        FakeAccount(
          id: newAccountId(),
          ci: ci,
          firstName: first,
          lastName: last,
          // Derivada de la CI: dos cuentas de la misma persona coinciden.
          birthDate: DateTime.utc(
            birthYear,
            1 + int.parse(ci) % 12,
            1 + int.parse(ci) % 27,
          ),
          email: '${first.toLowerCase()}.${last.toLowerCase()}@example.org'
              .replaceAll(RegExp('[áàä]'), 'a')
              .replaceAll(RegExp('[éè]'), 'e')
              .replaceAll(RegExp('[íì]'), 'i')
              .replaceAll(RegExp('[óò]'), 'o')
              .replaceAll(RegExp('[úù]'), 'u')
              .replaceAll(' ', ''),
          role: role,
          status: status,
          activated: activated,
          createdAt: daysAgo(createdDaysAgo),
          specialtyIds: specialtyIds,
          // Las que no se indican se derivan de la CI: celular uruguayo
          // válido y una dirección cualquiera.
          phone1: phone1 ?? '099${100000 + int.parse(ci) % 900000}',
          phone2: phone2,
          address: address ?? 'Calle $last ${100 + int.parse(ci) % 900}',
        ),
      );
    }

    add(
      '12345672',
      'Ana',
      'Rodríguez',
      UserRole.socio,
      createdDaysAgo: 120,
      birthYear: 1985,
      phone1: '099111222',
      address: 'Bulevar Artigas 1250',
    );
    add(
      '23456783',
      'Bruno',
      'Pereira',
      UserRole.funcionario,
      createdDaysAgo: 90,
      birthYear: 1990,
      phone1: '098333444',
      phone2: '099555666',
      address: 'Avenida Italia 2345',
    );
    // La cuenta de empleado anterior de Bruno, inactivada: no impide dar de
    // alta otra (CU 3.5.2 paso 9).
    add(
      '23456783',
      'Bruno',
      'Pereira',
      UserRole.medico,
      status: AccountStatus.inactive,
      createdDaysAgo: 400,
      birthYear: 1990,
      phone1: '098333444',
      phone2: '099555666',
      address: 'Avenida Italia 2345',
    );
    add(
      '34567894',
      'Carla',
      'Méndez',
      UserRole.medico,
      createdDaysAgo: 80,
      birthYear: 1978,
      specialtyIds: [1],
      phone1: '094555777',
      address: 'Calle Mercedes 870',
    );
    add(
      '45678905',
      'Diego',
      'Fernández',
      UserRole.administrador,
      createdDaysAgo: 200,
      birthYear: 1982,
      phone1: '099888999',
      address: 'Calle Colonia 1010',
    );
    add(
      '56789016',
      'Esteban',
      'Silva',
      UserRole.medico,
      createdDaysAgo: 70,
      birthYear: 1975,
      specialtyIds: [2],
    );
    add(
      '67890127',
      'Florencia',
      'Acosta',
      UserRole.medico,
      createdDaysAgo: 60,
      birthYear: 1988,
      specialtyIds: [1, 3],
      activated: false,
    );

    const firstNames = [
      'Lucía',
      'Mateo',
      'Valentina',
      'Santiago',
      'Camila',
      'Joaquín',
      'Martina',
      'Facundo',
      'Sofía',
      'Nicolás',
      'Julieta',
      'Agustín',
      'Paula',
      'Gonzalo',
      'Romina',
      'Federico',
      'Agustina',
      'Sebastián',
    ];
    const lastNames = [
      'González',
      'Rodríguez',
      'Gómez',
      'Fernández',
      'López',
      'Díaz',
      'Martínez',
      'Pérez',
      'García',
      'Sánchez',
      'Romero',
      'Sosa',
      'Álvarez',
      'Torres',
      'Ruiz',
      'Ramírez',
      'Flores',
      'Benítez',
    ];
    for (var i = 0; i < firstNames.length; i++) {
      final body = (2000000 + i * 91357).toString();
      final ci = '$body${calculateUruguayanCiVerifierDigit(body)}';
      add(
        ci,
        firstNames[i],
        lastNames[i],
        UserRole.socio,
        // Algunos socios inactivados y otros sin completar el primer ingreso.
        status: i % 6 == 5 ? AccountStatus.inactive : AccountStatus.active,
        activated: i % 4 != 3,
        createdDaysAgo: 1 + i * 9,
        birthYear: 1950 + i * 3,
      );
    }
  }
}

/// Un único estado en memoria por ejecución de la app.
final fakeAdminDatabaseProvider = Provider<FakeAdminDatabase>(
  (ref) => FakeAdminDatabase(),
);
