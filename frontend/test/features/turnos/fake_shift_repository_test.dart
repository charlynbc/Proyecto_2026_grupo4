import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ShiftNumber n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

void main() {
  late FakeAdminDatabase admin;
  late FakeShiftRepository repository;
  late int mendezId;
  late int silvaId;
  late int clinicId;

  NewWeeklyShift request({
    int? doctorId,
    int specialtyId = 1,
    DateTime? startDate,
    DateTime? endDate,
  }) => NewWeeklyShift(
    doctorId: doctorId ?? mendezId,
    specialtyId: specialtyId,
    clinicId: clinicId,
    weekday: 2,
    startDate: startDate ?? DateTime.utc(2026, 10, 20),
    endDate: endDate ?? DateTime.utc(2026, 11, 10),
    numbers: [n(1, '09:00', '09:20'), n(2, '09:20', '09:40')],
  );

  setUp(() {
    admin = FakeAdminDatabase();
    repository = FakeShiftRepository(
      FakeShiftDatabase(admin, seed: false),
      latency: Duration.zero,
    );
    int doctorId(String lastName) => admin.accounts
        .firstWhere((a) => a.role == UserRole.medico && a.lastName == lastName)
        .id;
    mendezId = doctorId('Méndez');
    silvaId = doctorId('Silva');
    clinicId = admin.clinics.first.id;
  });

  group('listDoctors', () {
    test(
      'lista solo médicos activos, ordenados por apellido y nombre',
      () async {
        final doctors = await repository.listDoctors();
        expect(doctors.map((d) => d.lastName), ['Acosta', 'Méndez', 'Silva']);
      },
    );

    test('trae las especialidades de cada médico', () async {
      final doctors = await repository.listDoctors();
      final acosta = doctors.firstWhere((d) => d.lastName == 'Acosta');
      expect(acosta.specialties.map((s) => s.id), [1, 3]);
    });

    test('con una especialidad, solo los médicos que la ejercen', () async {
      final doctors = await repository.listDoctors(specialtyId: 1);
      expect(doctors.map((d) => d.lastName), ['Acosta', 'Méndez']);
      final cardiology = await repository.listDoctors(specialtyId: 2);
      expect(cardiology.map((d) => d.lastName), ['Silva']);
    });

    test('una especialidad que nadie ejerce da una lista vacía', () async {
      expect(await repository.listDoctors(specialtyId: 9999), isEmpty);
    });
  });

  group('createWeeklyShift y getWeeklyShift', () {
    test(
      'devuelve la configuración con la cantidad de turnos generados',
      () async {
        final created = await repository.createWeeklyShift(request());
        expect(created.shiftCount, 4);
        expect(created.weekday, 2);
        expect(created.doctor.id, mendezId);
        expect(created.specialty.id, 1);
        expect(created.clinic.id, clinicId);
        expect(created.startDate, DateTime.utc(2026, 10, 20));
        expect(created.endDate, DateTime.utc(2026, 11, 10));
        expect(created.numbers.map((e) => e.number), [1, 2]);
      },
    );

    test('la configuración creada se puede consultar por id', () async {
      final created = await repository.createWeeklyShift(request());
      final fetched = await repository.getWeeklyShift(created.id);
      expect(fetched.id, created.id);
      expect(fetched.shiftCount, 4);
      expect(fetched.numbers.length, 2);
    });

    test('un id que no existe no se encuentra', () async {
      await expectLater(
        repository.getWeeklyShift(9999),
        throwsA(isA<ShiftNotFoundException>()),
      );
    });

    test(
      'un cruce llega como OverlappingShiftException con el detalle',
      () async {
        await repository.createWeeklyShift(request());
        await expectLater(
          repository.createWeeklyShift(request()),
          throwsA(
            isA<OverlappingShiftException>().having(
              (e) => e.message,
              'message',
              allOf(contains('20/10/2026'), contains('consultorio')),
            ),
          ),
        );
      },
    );

    test('una vigencia sin el día elegido es VALIDACION', () async {
      await expectLater(
        repository.createWeeklyShift(
          request(
            startDate: DateTime.utc(2026, 10, 21),
            endDate: DateTime.utc(2026, 10, 23),
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

    test('la especialidad tiene que ser del médico', () async {
      await expectLater(
        repository.createWeeklyShift(request(doctorId: silvaId)),
        throwsA(isA<SpecialtyNotOfDoctorException>()),
      );
    });

    test('un médico inactivo no puede recibir turnos', () async {
      final inactive = admin.accounts.firstWhere(
        (a) =>
            a.role == UserRole.medico &&
            a.lastName == 'Pereira' &&
            a.status.name == 'inactive',
      );
      await expectLater(
        repository.createWeeklyShift(request(doctorId: inactive.id)),
        throwsA(isA<InactiveDoctorException>()),
      );
    });
  });

  test('no modifica FakeAdminDatabase', () async {
    final accountsBefore = admin.accounts.length;
    final specialtiesBefore = admin.specialties.length;
    final clinicsBefore = admin.clinics.length;
    await repository.listDoctors();
    await repository.createWeeklyShift(request());
    expect(admin.accounts.length, accountsBefore);
    expect(admin.specialties.length, specialtiesBefore);
    expect(admin.clinics.length, clinicsBefore);
  });
}
