import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/models/referral.dart';
import 'package:agenda_medica/features/agenda/repositories/agenda_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/fake_agenda_repository.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter_test/flutter_test.dart';

// Hoy fijo (clave de día de Uruguay): 24/10/2026. Los pases de la semilla
// caen en 19/10/2026 y 14/09/2026 (emitidos) y en 18/11/2026 y 22/10/2026
// (vencimientos).
final _today = DateTime.utc(2026, 10, 24);

/// Los catálogos que ve la app: Medicina General (id 1, sin pase), Cardiología
/// (id 2, con pase) y Dermatología (id 3, con pase).
class _Env {
  _Env(DateTime today) {
    admin = FakeAdminDatabase();
    db = FakeDatabase(today: today, admin: admin);
    repo = FakeAgendaRepository(
      db,
      admin,
      latency: Duration.zero,
      clock: () => DateTime.utc(today.year, today.month, today.day, 15),
    );
  }

  late final FakeAdminDatabase admin;
  late final FakeDatabase db;
  late final FakeAgendaRepository repo;

  Specialty get general => admin.specialties[0];
  Specialty get cardiology => admin.specialties[1];
  Specialty get dermatology => admin.specialties[2];

  /// El último número libre de la especialidad: el más lejano, siempre dentro
  /// de la anticipación máxima.
  Future<AvailableNumber> lastNumber(Specialty specialty) async =>
      (await repo.listAvailability(
        AvailabilityQuery(specialtyId: specialty.id),
      )).last;
}

Referral _referral(int id, Specialty specialty, DateTime expiresOn) => Referral(
  id: id,
  specialty: specialty,
  issuedAt: DateTime.utc(2026, 10, 1, 12),
  expiresOn: expiresOn,
);

/// Una consulta de Cardiología que usa el pase [referralId], en el estado
/// guardado [status].
Appointment _appointmentUsing(int referralId, String status, Specialty s) =>
    Appointment(
      id: 900 + referralId,
      status: status,
      date: DateTime.utc(2026, 9, 1),
      number: 1,
      startMinutes: 8 * 60,
      endMinutes: 8 * 60 + 30,
      doctor: DoctorRef(id: 2, firstName: 'Esteban', lastName: 'Silva'),
      specialty: s,
      clinic: Clinic(id: 1, name: 'Consultorio 3', location: 'Planta baja'),
      referralId: referralId,
      bookedAt: DateTime.utc(2026, 8, 20, 12),
      cancelledAt: status.startsWith('CANCELADA')
          ? DateTime.utc(2026, 8, 25, 12)
          : null,
      cancellationReason: null,
    );

Matcher _failsWith(BookingFailure failure) => throwsA(
  isA<BookingException>().having((e) => e.failure, 'failure', failure),
);

List<int> _ids(Iterable<Referral> referrals) => [
  for (final r in referrals) r.id,
];

void main() {
  group('semilla de pases', () {
    test('trae dos pases de Cardiología: el 1 vigente y el 2 vencido', () {
      final env = _Env(_today);

      final referrals = env.db.referrals;

      expect(_ids(referrals), [1, 2]);
      expect(referrals[0].specialty.id, 2);
      expect(referrals[0].specialty.name, 'Cardiología');
      expect(referrals[0].issuedAt, DateTime.utc(2026, 10, 19, 12));
      expect(referrals[0].expiresOn, DateTime.utc(2026, 11, 18));
      expect(referrals[1].specialty.id, 2);
      expect(referrals[1].issuedAt, DateTime.utc(2026, 9, 14, 12));
      expect(referrals[1].expiresOn, DateTime.utc(2026, 10, 22));
    });

    test('las fechas se mueven con el día de hoy', () {
      final env = _Env(DateTime.utc(2026, 12, 1));

      expect(env.db.referrals[0].issuedAt, DateTime.utc(2026, 11, 26, 12));
      expect(env.db.referrals[0].expiresOn, DateTime.utc(2026, 12, 26));
      expect(env.db.referrals[1].issuedAt, DateTime.utc(2026, 10, 22, 12));
      expect(env.db.referrals[1].expiresOn, DateTime.utc(2026, 11, 29));
    });

    test('todos los números de Cardiología caen antes del vencimiento del '
        'pase 1', () {
      final env = _Env(_today);
      final expiresOn = env.db.referrals[0].expiresOn;
      final cardiologyNumbers = env.db.numbers.where((n) => n.doctorId == 2);

      expect(cardiologyNumbers, isNotEmpty);
      for (final number in cardiologyNumbers) {
        final start = UruguayTime.toUruguay(number.start);
        final day = DateTime.utc(start.year, start.month, start.day);
        expect(day.isAfter(expiresOn), isFalse, reason: '$day');
      }
    });
  });

  group('listReferrals', () {
    test('con la semilla devuelve solo el pase 1', () async {
      final env = _Env(_today);

      final referrals = await env.repo.listReferrals();

      expect(_ids(referrals), [1]);
      expect(referrals[0].expiresOn, DateTime.utc(2026, 11, 18));
    });

    test('un pase que vence hoy se lista; uno que venció ayer, no', () async {
      final env = _Env(_today);
      env.db.referrals
        ..add(_referral(10, env.cardiology, DateTime.utc(2026, 10, 24)))
        ..add(_referral(11, env.cardiology, DateTime.utc(2026, 10, 23)));

      // El 10 vence el 24/10 y el 1 el 18/11: va primero el que vence antes.
      expect(_ids(await env.repo.listReferrals()), [10, 1]);
    });

    // Los cinco estados que se guardan (esquema, ck_consulta_estado). Usan el
    // pase los que no son una cancelación; NO_ASISTIO y NO_ATENDIDA se
    // calculan y nunca se guardan.
    const usedStatuses = ['AGENDADA', 'ATENDIDA', 'NO_SE_PRESENTO'];
    const releasedStatuses = ['CANCELADA_SOCIO', 'CANCELADA_INSTITUCION'];

    for (final status in usedStatuses) {
      test('un pase usado por una consulta $status no se lista', () async {
        final env = _Env(_today);
        env.db.appointments.add(_appointmentUsing(1, status, env.cardiology));

        expect(await env.repo.listReferrals(), isEmpty);
      });
    }

    for (final status in releasedStatuses) {
      test('un pase de una consulta $status se lista de nuevo', () async {
        final env = _Env(_today);
        env.db.appointments.add(_appointmentUsing(1, status, env.cardiology));

        expect(_ids(await env.repo.listReferrals()), [1]);
      });
    }

    test('ordena por vencimiento y después por id', () async {
      final env = _Env(_today);
      env.db.referrals
        ..add(_referral(21, env.cardiology, DateTime.utc(2026, 11, 30)))
        ..add(_referral(20, env.cardiology, DateTime.utc(2026, 11, 30)))
        ..add(_referral(22, env.cardiology, DateTime.utc(2026, 11, 10)));

      expect(_ids(await env.repo.listReferrals()), [22, 1, 20, 21]);
    });
  });

  group('book con pase', () {
    test(
      'con el pase 1 agenda, deja su id en la consulta y lo consume',
      () async {
        final env = _Env(_today);
        final number = await env.lastNumber(env.cardiology);

        final appointment = await env.repo.book(
          numberId: number.numberId,
          referralId: 1,
        );

        expect(appointment.referralId, 1);
        expect(appointment.specialty.name, 'Cardiología');
        expect(await env.repo.listReferrals(), isEmpty);
      },
    );

    test(
      'sin pase en una especialidad que lo pide es PASE_NO_VALIDO',
      () async {
        final env = _Env(_today);
        final number = await env.lastNumber(env.cardiology);

        await expectLater(
          env.repo.book(numberId: number.numberId),
          _failsWith(BookingFailure.invalidReferral),
        );
      },
    );

    test('un pase que no existe es PASE_NO_VALIDO', () async {
      final env = _Env(_today);
      final number = await env.lastNumber(env.cardiology);

      await expectLater(
        env.repo.book(numberId: number.numberId, referralId: 999),
        _failsWith(BookingFailure.invalidReferral),
      );
    });

    test('el pase vencido (el 2) es PASE_NO_VALIDO', () async {
      final env = _Env(_today);
      final number = await env.lastNumber(env.cardiology);

      await expectLater(
        env.repo.book(numberId: number.numberId, referralId: 2),
        _failsWith(BookingFailure.invalidReferral),
      );
    });

    test('un pase de otra especialidad es PASE_NO_VALIDO', () async {
      final env = _Env(_today);
      final number = await env.lastNumber(env.cardiology);
      env.db.referrals.add(
        _referral(30, env.dermatology, DateTime.utc(2026, 12, 31)),
      );

      await expectLater(
        env.repo.book(numberId: number.numberId, referralId: 30),
        _failsWith(BookingFailure.invalidReferral),
      );
    });

    test(
      'un pase que vence el día anterior a la consulta es PASE_NO_VALIDO',
      () async {
        final env = _Env(_today);
        final number = await env.lastNumber(env.cardiology);
        env.db.referrals.add(
          _referral(
            40,
            env.cardiology,
            number.date.subtract(const Duration(days: 1)),
          ),
        );

        await expectLater(
          env.repo.book(numberId: number.numberId, referralId: 40),
          _failsWith(BookingFailure.invalidReferral),
        );
      },
    );

    test('un pase que vence el mismo día de la consulta sirve', () async {
      final env = _Env(_today);
      final number = await env.lastNumber(env.cardiology);
      env.db.referrals.add(_referral(41, env.cardiology, number.date));

      final appointment = await env.repo.book(
        numberId: number.numberId,
        referralId: 41,
      );

      expect(appointment.referralId, 41);
    });

    test('un pase usado por otra consulta es PASE_NO_VALIDO', () async {
      final env = _Env(_today);
      final number = await env.lastNumber(env.cardiology);
      // Una ATENDIDA no cuenta para el límite por especialidad, pero sí usa el
      // pase.
      env.db.appointments.add(_appointmentUsing(1, 'ATENDIDA', env.cardiology));

      await expectLater(
        env.repo.book(numberId: number.numberId, referralId: 1),
        _failsWith(BookingFailure.invalidReferral),
      );
    });

    test('un pase en una especialidad que no lo pide es VALIDACION', () async {
      final env = _Env(_today);
      final number = await env.lastNumber(env.general);

      await expectLater(
        env.repo.book(numberId: number.numberId, referralId: 1),
        _failsWith(BookingFailure.validation),
      );
    });

    test('el límite de consultas se valida antes que el pase', () async {
      final env = _Env(_today);
      final number = await env.lastNumber(env.cardiology);
      // La de la semilla (Dermatología) y estas dos suman tres AGENDADA.
      env.db.appointments
        ..add(_appointmentUsing(50, 'AGENDADA', env.general))
        ..add(_appointmentUsing(51, 'AGENDADA', env.general));

      await expectLater(
        env.repo.book(numberId: number.numberId),
        _failsWith(BookingFailure.totalLimit),
      );
    });
  });
}
