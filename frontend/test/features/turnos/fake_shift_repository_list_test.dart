import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shift_listing_data.dart';

/// Ver `buildListingDb`: 32 fechas, la 1.ª es la de Silva del 19/10 a las 08:00.
void main() {
  late FakeAdminDatabase admin;
  late FakeShiftRepository repository;
  late int mendezId;
  late int silvaId;
  late int acostaId;

  setUp(() {
    admin = FakeAdminDatabase();
    repository = FakeShiftRepository(
      buildListingDb(admin),
      latency: Duration.zero,
    );
    int doctor(String lastName) => admin.accounts
        .firstWhere((a) => a.lastName == lastName && a.specialtyIds.isNotEmpty)
        .id;
    mendezId = doctor('Méndez');
    silvaId = doctor('Silva');
    acostaId = doctor('Acosta');
  });

  group('paginación', () {
    test('sin filtros: página 0 de 20 sobre 32 turnos', () async {
      final page = await repository.listShifts(const ShiftFilters());
      expect(page.page, 0);
      expect(page.size, 20);
      expect(page.total, 32);
      expect(page.items.length, 20);
      expect(page.pageCount, 2);
    });

    test('la segunda página trae los 12 que faltan', () async {
      final page = await repository.listShifts(const ShiftFilters(page: 1));
      expect(page.page, 1);
      expect(page.items.length, 12);
      expect(page.total, 32);
      expect(page.hasNext, isFalse);
    });

    test('las dos páginas no repiten ni pierden turnos', () async {
      final first = await repository.listShifts(const ShiftFilters());
      final second = await repository.listShifts(const ShiftFilters(page: 1));
      final ids = [...first.items, ...second.items].map((s) => s.id).toList();
      expect(ids.toSet().length, 32);
    });

    test('respeta el tamaño pedido', () async {
      final page = await repository.listShifts(const ShiftFilters(size: 5));
      expect(page.items.length, 5);
      expect(page.size, 5);
      expect(page.pageCount, 7);
    });

    test('una página fuera de rango viene vacía, con el total', () async {
      final page = await repository.listShifts(const ShiftFilters(page: 9));
      expect(page.items, isEmpty);
      expect(page.total, 32);
    });

    test('con exactamente 20 resultados hay una sola página', () async {
      final page = await repository.listShifts(
        ShiftFilters(fromDate: DateTime.utc(2026, 11, 12)),
      );
      expect(page.total, 20);
      expect(page.pageCount, 1);
      expect(page.hasNext, isFalse);
    });
  });

  group('filtros', () {
    Future<int> total(ShiftFilters filters) async =>
        (await repository.listShifts(filters)).total;

    test('por médico', () async {
      expect(await total(ShiftFilters(doctorId: mendezId)), 4);
      expect(await total(ShiftFilters(doctorId: silvaId)), 5);
      expect(await total(ShiftFilters(doctorId: acostaId)), 23);
    });

    test('por especialidad', () async {
      expect(await total(const ShiftFilters(specialtyId: 2)), 5);
      expect(await total(const ShiftFilters(specialtyId: 1)), 4);
    });

    test('por día de la semana, con 1 = lunes', () async {
      expect(await total(const ShiftFilters(weekday: 1)), 24);
      expect(await total(const ShiftFilters(weekday: 2)), 4);
      expect(await total(const ShiftFilters(weekday: 4)), 4);
      expect(await total(const ShiftFilters(weekday: 7)), 0);
    });

    test('por estado', () async {
      expect(await total(const ShiftFilters(state: ShiftState.suspended)), 2);
      expect(await total(const ShiftFilters(state: ShiftState.active)), 30);
    });

    test('por rango de fechas, inclusivo en los dos extremos', () async {
      final page = await repository.listShifts(
        ShiftFilters(
          fromDate: DateTime.utc(2026, 10, 20),
          toDate: DateTime.utc(2026, 10, 22),
        ),
      );
      expect(page.items.map((s) => s.date), [
        DateTime.utc(2026, 10, 20),
        DateTime.utc(2026, 10, 22),
      ]);
      expect(
        await total(
          ShiftFilters(
            fromDate: DateTime.utc(2026, 10, 20),
            toDate: DateTime.utc(2026, 10, 20),
          ),
        ),
        1,
      );
    });

    test('con un solo extremo del rango', () async {
      expect(await total(ShiftFilters(toDate: DateTime.utc(2026, 10, 19))), 2);
      expect(await total(ShiftFilters(fromDate: DateTime.utc(2027, 3, 22))), 1);
    });

    test('los filtros se combinan', () async {
      expect(
        await total(
          ShiftFilters(doctorId: mendezId, state: ShiftState.suspended),
        ),
        1,
      );
      expect(await total(ShiftFilters(doctorId: silvaId, weekday: 1)), 1);
      expect(
        await total(
          ShiftFilters(
            specialtyId: 3,
            weekday: 1,
            fromDate: DateTime.utc(2026, 11, 1),
            toDate: DateTime.utc(2026, 11, 30),
          ),
        ),
        // Los lunes de noviembre: 2, 9, 16, 23 y 30.
        5,
      );
    });

    test('sin coincidencias: lista vacía y total 0', () async {
      final page = await repository.listShifts(
        ShiftFilters(doctorId: mendezId, weekday: 1),
      );
      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.pageCount, 1);
    });

    test('un rango con "desde" posterior a "hasta" es VALIDACION', () async {
      await expectLater(
        repository.listShifts(
          ShiftFilters(
            fromDate: DateTime.utc(2026, 11, 1),
            toDate: DateTime.utc(2026, 10, 1),
          ),
        ),
        throwsA(
          isA<ShiftValidationException>().having(
            (e) => e.code,
            'code',
            'VALIDACION',
          ),
        ),
      );
    });
  });

  // Decisión: `sentido` invierte el criterio principal. En `fecha` eso es el
  // par (fecha, horario); en `medico` y `especialidad`, los empates se
  // desempatan siempre por fecha y horario ascendentes.
  group('orden', () {
    test('por defecto: fecha y luego horario, ascendente', () async {
      final page = await repository.listShifts(const ShiftFilters());
      final first = page.items[0];
      final second = page.items[1];
      expect(first.date, DateTime.utc(2026, 10, 19));
      expect(first.startMinutes, 8 * 60);
      expect(first.doctor.lastName, 'Silva');
      expect(second.date, DateTime.utc(2026, 10, 19));
      expect(second.startMinutes, 10 * 60);
      expect(second.doctor.lastName, 'Acosta');
      for (var i = 0; i + 1 < page.items.length; i++) {
        final a = page.items[i];
        final b = page.items[i + 1];
        final inOrder =
            a.date.isBefore(b.date) ||
            (a.date == b.date && a.startMinutes <= b.startMinutes);
        expect(inOrder, isTrue, reason: 'filas $i y ${i + 1}');
      }
    });

    test('por fecha descendente empieza por la más lejana', () async {
      final page = await repository.listShifts(
        const ShiftFilters(ascending: false),
      );
      expect(page.items.first.date, DateTime.utc(2027, 3, 22));
      expect(page.items.last.date.isBefore(page.items.first.date), isTrue);
    });

    test(
      'por médico ascendente: apellido, y dentro de cada uno por fecha',
      () async {
        final page = await repository.listShifts(
          const ShiftFilters(order: ShiftOrder.doctor),
        );
        expect(page.items.every((s) => s.doctor.lastName == 'Acosta'), isTrue);
        expect(page.items.first.date, DateTime.utc(2026, 10, 19));
        expect(page.items[1].date, DateTime.utc(2026, 10, 26));
      },
    );

    test('por médico descendente empieza por Silva, por fecha', () async {
      final page = await repository.listShifts(
        const ShiftFilters(order: ShiftOrder.doctor, ascending: false),
      );
      final firstFive = page.items.take(5).toList();
      expect(firstFive.every((s) => s.doctor.lastName == 'Silva'), isTrue);
      expect(firstFive.first.date, DateTime.utc(2026, 10, 19));
      expect(firstFive.first.startMinutes, 8 * 60);
      expect(page.items[5].doctor.lastName, 'Méndez');
    });

    test('por especialidad ascendente: Cardiología primero', () async {
      final page = await repository.listShifts(
        const ShiftFilters(order: ShiftOrder.specialty),
      );
      expect(page.items.first.specialty.name, 'Cardiología');
      expect(page.items.take(5).every((s) => s.specialty.id == 2), isTrue);
      expect(page.items[5].specialty.name, 'Dermatología');
    });

    test('por especialidad descendente: Medicina General primero', () async {
      final page = await repository.listShifts(
        const ShiftFilters(order: ShiftOrder.specialty, ascending: false),
      );
      expect(page.items.first.specialty.name, 'Medicina General');
      expect(page.items.first.date, DateTime.utc(2026, 10, 20));
    });

    test('el orden vale para todas las páginas', () async {
      final first = await repository.listShifts(const ShiftFilters());
      final second = await repository.listShifts(const ShiftFilters(page: 1));
      expect(
        second.items.first.date.isAfter(first.items.last.date) ||
            second.items.first.date == first.items.last.date,
        isTrue,
      );
    });
  });

  // Criterio exacto: por médico se ordena por apellido y, si empatan, por
  // nombre; por especialidad, por su nombre. En los tres casos se ignoran
  // mayúsculas y tildes (la ñ cuenta como n) y los empates restantes se
  // desempatan por fecha y horario ascendentes.
  group('criterio de orden por médico y por especialidad', () {
    var hour = 8;

    int addDoctor(String first, String last, int specialtyId) {
      final id = admin.newAccountId();
      admin.accounts.add(
        FakeAccount(
          id: id,
          ci: '1000000$id',
          firstName: first,
          lastName: last,
          birthDate: DateTime.utc(1980, 1, 1),
          email: '$id@example.org',
          role: UserRole.medico,
          createdAt: DateTime.utc(2026, 1, 1),
          specialtyIds: [specialtyId],
        ),
      );
      return id;
    }

    // Un miércoles (21/10/2026), cada uno a una hora distinta del consultorio 3.
    Future<void> addWednesdayShift(int doctorId, int specialtyId) async {
      final start = hour++ * 60;
      await repository.createWeeklyShift(
        NewWeeklyShift(
          doctorId: doctorId,
          specialtyId: specialtyId,
          clinicId: admin.clinics[0].id,
          weekday: 3,
          startDate: DateTime.utc(2026, 10, 21),
          endDate: DateTime.utc(2026, 10, 21),
          numbers: [
            ShiftNumber(number: 1, startMinutes: start, endMinutes: start + 20),
          ],
        ),
      );
    }

    Future<List<String>> doctorsInOrder({required bool ascending}) async {
      final page = await repository.listShifts(
        ShiftFilters(order: ShiftOrder.doctor, ascending: ascending, size: 100),
      );
      final names = <String>[];
      for (final shift in page.items) {
        final name = shift.doctor.fullName;
        if (names.isEmpty || names.last != name) names.add(name);
      }
      return names;
    }

    test('por médico: apellido, luego nombre, sin mayúsculas ni tildes', () async {
      // Con tildes y mayúsculas, el orden "crudo" (por código) los pondría
      // al final: Álvarez (Á) y bravo (b minúscula) quedarían después de Silva.
      await addWednesdayShift(addDoctor('Hugo', 'Álvarez', 1), 1);
      await addWednesdayShift(addDoctor('Lola', 'bravo', 1), 1);
      await addWednesdayShift(addDoctor('Ana', 'Silva', 2), 2);

      final ascending = await doctorsInOrder(ascending: true);
      expect(ascending, [
        'Florencia Acosta',
        'Hugo Álvarez',
        'Lola bravo',
        'Carla Méndez',
        'Ana Silva', // Mismo apellido que Esteban Silva: desempata el nombre.
        'Esteban Silva',
      ]);
      expect(ascending.toSet().length, ascending.length, reason: 'contiguos');
      expect(await doctorsInOrder(ascending: false), ascending.reversed);
    });

    test('por especialidad: su nombre, sin mayúsculas ni tildes', () async {
      // Óptica (Ó) quedaría después de Urología con el orden "crudo".
      final optics = admin.newSpecialtyId();
      admin.specialties.add(
        Specialty(id: optics, name: 'Óptica', requiresReferral: false),
      );
      final urology = admin.newSpecialtyId();
      admin.specialties.add(
        Specialty(id: urology, name: 'Urología', requiresReferral: false),
      );
      await addWednesdayShift(addDoctor('Rosa', 'Gómez', optics), optics);
      await addWednesdayShift(addDoctor('Paula', 'Ruiz', urology), urology);

      Future<List<String>> specialtiesInOrder({required bool ascending}) async {
        final page = await repository.listShifts(
          ShiftFilters(
            order: ShiftOrder.specialty,
            ascending: ascending,
            size: 100,
          ),
        );
        final names = <String>[];
        for (final shift in page.items) {
          final name = shift.specialty.name;
          if (names.isEmpty || names.last != name) names.add(name);
        }
        return names;
      }

      final ascending = await specialtiesInOrder(ascending: true);
      expect(ascending, [
        'Cardiología',
        'Dermatología',
        'Medicina General',
        'Óptica',
        'Urología',
      ]);
      expect(await specialtiesInOrder(ascending: false), ascending.reversed);
    });

    test(
      'dentro de un mismo médico, por fecha y horario ascendentes',
      () async {
        final page = await repository.listShifts(
          ShiftFilters(
            order: ShiftOrder.doctor,
            ascending: false,
            doctorId: silvaId,
          ),
        );
        final keys = [for (final s in page.items) (s.date, s.startMinutes)];
        for (var i = 0; i + 1 < keys.length; i++) {
          final (aDate, aStart) = keys[i];
          final (bDate, bStart) = keys[i + 1];
          expect(
            aDate.isBefore(bDate) || (aDate == bDate && aStart <= bStart),
            isTrue,
          );
        }
      },
    );
  });

  // Decisión: el contrato dice `size` de 1 a 100 y `page` ≥ 0 (1.3) pero no
  // qué responde fuera de rango. El fake supone `400 VALIDACION`.
  group('tamaño y número de página fuera de rango', () {
    for (final size in [0, -1, 101, 1000]) {
      test('size $size es VALIDACION', () async {
        await expectLater(
          repository.listShifts(ShiftFilters(size: size)),
          throwsA(isA<ShiftValidationException>()),
        );
      });
    }

    test('page negativa es VALIDACION', () async {
      await expectLater(
        repository.listShifts(const ShiftFilters(page: -1)),
        throwsA(isA<ShiftValidationException>()),
      );
    });

    test('los extremos 1 y 100 son válidos', () async {
      final one = await repository.listShifts(const ShiftFilters(size: 1));
      expect(one.items.length, 1);
      expect(one.pageCount, 32);
      final hundred = await repository.listShifts(
        const ShiftFilters(size: 100),
      );
      expect(hundred.items.length, 32);
      expect(hundred.pageCount, 1);
    });
  });

  group('cada turno del listado', () {
    test('trae todos los datos del contrato, anidados', () async {
      final page = await repository.listShifts(const ShiftFilters());
      final shift = page.items[1]; // Acosta, lunes 19/10, 10:00 a 11:00.
      expect(shift.weekday, 1);
      expect(shift.startMinutes, 10 * 60);
      expect(shift.endMinutes, 11 * 60);
      expect(shift.numberCount, 3);
      expect(shift.state, ShiftState.active);
      expect(shift.doctor.id, acostaId);
      expect(shift.doctor.firstName, 'Florencia');
      expect(shift.doctor.lastName, 'Acosta');
      expect(shift.specialty.name, 'Dermatología');
      expect(shift.specialty.requiresReferral, isTrue);
      expect(shift.clinic.name, 'Consultorio 12');
      expect(shift.clinic.location, 'Piso 2');
      expect(shift.weeklyShiftId, isPositive);
    });

    test(
      'el horario va del inicio del primer número al fin del último',
      () async {
        final page = await repository.listShifts(
          ShiftFilters(doctorId: silvaId, weekday: 4),
        );
        expect(page.items.first.startMinutes, 15 * 60);
        expect(page.items.first.endMinutes, 16 * 60);
        expect(page.items.first.numberCount, 2);
      },
    );

    test(
      'los turnos de una misma configuración comparten weeklyShiftId',
      () async {
        final page = await repository.listShifts(
          ShiftFilters(doctorId: mendezId),
        );
        expect(page.items.map((s) => s.weeklyShiftId).toSet().length, 1);
      },
    );

    test('un turno suspendido se ve como suspendido', () async {
      final page = await repository.listShifts(
        ShiftFilters(doctorId: mendezId, state: ShiftState.suspended),
      );
      expect(page.items.single.date, DateTime.utc(2026, 10, 27));
      expect(page.items.single.state, ShiftState.suspended);
    });

    test('un turno semanal nuevo aparece en el listado', () async {
      final before = await repository.listShifts(const ShiftFilters());
      expect(before.total, 32);
      // Méndez y el consultorio 3 solo tienen turnos los martes: los
      // miércoles 21/10, 28/10, 4/11 y 11/11 están libres.
      final created = await repository.createWeeklyShift(
        NewWeeklyShift(
          doctorId: mendezId,
          specialtyId: 1,
          clinicId: admin.clinics[0].id,
          weekday: 3,
          startDate: DateTime.utc(2026, 10, 21),
          endDate: DateTime.utc(2026, 11, 11),
          numbers: [
            ShiftNumber(
              number: 1,
              startMinutes: 9 * 60,
              endMinutes: 9 * 60 + 20,
            ),
          ],
        ),
      );
      expect(created.shiftCount, 4);
      final after = await repository.listShifts(const ShiftFilters());
      expect(after.total, 36);
      final wednesdays = await repository.listShifts(
        const ShiftFilters(weekday: 3),
      );
      expect(wednesdays.total, 4);
      expect(
        wednesdays.items.every((s) => s.weeklyShiftId == created.id),
        isTrue,
      );
    });
  });
}
