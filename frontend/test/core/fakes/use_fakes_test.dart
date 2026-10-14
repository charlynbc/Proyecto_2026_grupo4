import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/core/validators/uruguayan_ci_validator.dart';
import 'package:agenda_medica/features/agenda/models/time_slot.dart';
import 'package:agenda_medica/features/agenda/providers/agenda_repository_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/agenda_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/api_agenda_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_agenda_repository.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/api_auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_auth_repository.dart';
import 'package:agenda_medica/features/reservas/providers/reservation_repository_provider.dart';
import 'package:agenda_medica/features/reservas/repositories/api_reservation_repository.dart';
import 'package:agenda_medica/features/reservas/repositories/fake_reservation_repository.dart';
import 'package:agenda_medica/features/reservas/repositories/reservation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({required bool useFakes}) {
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(useFakes),
      // Un Dio liso: el real configura cookies con path_provider, que no
      // existe en el entorno de test.
      dioProvider.overrideWith((ref) async => Dio()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group(
    'con USE_FAKES=true los providers devuelven la implementación falsa',
    () {
      test('auth', () async {
        final repo = await _container(useFakes: true)
            .read(authRepositoryProvider.future);
        expect(repo, isA<FakeAuthRepository>());
      });

      test('agenda', () async {
        final repo = await _container(useFakes: true)
            .read(agendaRepositoryProvider.future);
        expect(repo, isA<FakeAgendaRepository>());
      });

      test('reservas', () async {
        final repo = await _container(useFakes: true)
            .read(reservationRepositoryProvider.future);
        expect(repo, isA<FakeReservationRepository>());
      });
    },
  );

  group('con USE_FAKES=false los providers devuelven la API', () {
    test('auth', () async {
      final repo = await _container(useFakes: false)
          .read(authRepositoryProvider.future);
      expect(repo, isA<ApiAuthRepository>());
    });

    test('agenda', () async {
      final repo = await _container(useFakes: false)
          .read(agendaRepositoryProvider.future);
      expect(repo, isA<ApiAgendaRepository>());
    });

    test('reservas', () async {
      final repo = await _container(useFakes: false)
          .read(reservationRepositoryProvider.future);
      expect(repo, isA<ApiReservationRepository>());
    });
  });

  test('USE_FAKES es false por defecto', () {
    expect(AppConfig.useFakes, isFalse);
  });

  group('datos de prueba', () {
    test('todas las cédulas son válidas y hay una persona por rol', () {
      for (final person in TestData.people) {
        expect(isValidUruguayanCi(person.ci), isTrue, reason: person.ci);
      }
      final roles = TestData.people.map((p) => p.role).toSet();
      expect(roles, {kRoleMember, kRoleStaff, kRoleDoctor, kRoleAdmin});
    });

    test('4 especialidades (2 con pase), 3 consultorios y 3 médicos', () {
      expect(TestData.specialties, hasLength(4));
      expect(
        TestData.specialties.where((s) => s.requiresReferral),
        hasLength(2),
      );
      expect(TestData.clinics, hasLength(3));
      expect(TestData.doctors, hasLength(3));
    });

    test('hay turnos con números en las próximas semanas', () {
      final shifts = TestData.shiftsFrom(UruguayTime.today());
      expect(shifts, isNotEmpty);
      expect(
        shifts.every((s) => s.numbers.length == TestData.numbersPerShift),
        isTrue,
      );
    });
  });

  group('login falso', () {
    Future<(SessionNotifier, AuthRepository, ProviderContainer)> build() async {
      final container = _container(useFakes: true);
      final repo = await container.read(authRepositoryProvider.future);
      return (container.read(sessionProvider.notifier), repo, container);
    }

    test(
      'acepta cada persona con la contraseña de prueba y da su rol',
      () async {
        final (_, repo, container) = await build();
        for (final person in TestData.people) {
          await repo.login(ci: person.ci, password: kTestPassword);
          final session = container.read(sessionProvider);
          expect(session.isAuthenticated, isTrue);
          expect(session.role, person.role);
        }
      },
    );

    test('rechaza contraseña o cédula desconocida (401)', () async {
      final (_, repo, _) = await build();
      expect(
        repo.login(ci: TestData.people.first.ci, password: 'otra'),
        throwsA(isA<InvalidCredentialsException>()),
      );
      expect(
        repo.login(ci: '11111111', password: kTestPassword),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });
  });

  group('agenda y reservas falsas', () {
    test(
      'reservar quita el horario y aparece en mis reservas; cancelar lo libera',
      () async {
        final db = FakeDatabase(today: UruguayTime.today());
        final agenda = FakeAgendaRepository(db, latency: Duration.zero);
        final reservations = FakeReservationRepository(
          db,
          latency: Duration.zero,
        );

        // Un horario libre, que no sea de los que fallan a propósito.
        TimeSlot? free;
        for (final doctor in await agenda.listProfessionals()) {
          for (final day in UruguayTime.nextDays(21)) {
            final slots = await agenda.listTimeSlots(
              professionalId: doctor.id,
              day: day,
            );
            for (final slot in slots) {
              if (slot.id % 100 == 0) free ??= slot;
            }
          }
        }
        expect(free, isNotNull);

        final before = (await reservations.listMine()).length;
        await agenda.reserve(timeSlotId: free!.id);
        final after = await reservations.listMine();
        expect(after, hasLength(before + 1));

        await expectLater(
          agenda.reserve(timeSlotId: free.id),
          throwsA(isA<TimeSlotTakenException>()),
        );

        await reservations.cancel(reservationId: after.last.id);
        await expectLater(
          reservations.cancel(reservationId: after.last.id),
          throwsA(isA<ReservationNotFoundException>()),
        );
      },
    );
  });
}
