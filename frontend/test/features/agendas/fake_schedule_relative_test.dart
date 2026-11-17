import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/features/agendas/models/schedule_entry.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_repository_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_clock_provider.dart';
import 'package:agenda_medica/features/agendas/providers/staff_cancellation_repository_provider.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_schedule_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_staff_cancellation_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/staff_cancellation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Con `USE_FAKES` las consultas agendadas de ejemplo se arman con el reloj:
/// la 9001 empieza dentro de una hora (no se puede cancelar: faltan menos de
/// dos horas) y la 9004 dentro de tres (sí se puede). Así se prueban a mano
/// los dos caminos a cualquier hora del día. Las demás consultas de ejemplo
/// no cambian.

/// [hour]:[minute] de Uruguay (UTC-3, sin horario de verano) como instante.
DateTime _at(
  int year,
  int month,
  int day,
  int hour,
  int minute, [
  int second = 0,
]) => DateTime.utc(year, month, day, hour + 3, minute, second);

FakeScheduleRepository _repository(DateTime now) =>
    FakeScheduleRepository.relativeTo(latency: Duration.zero, clock: () => now);

Future<Map<int, ScheduleEntry>> _entries(
  FakeScheduleRepository repository,
) async {
  final page = await repository.search(const ScheduleFilters(date: null));
  return {for (final entry in page.items) entry.appointmentId: entry};
}

void _expectEntry(
  ScheduleEntry entry, {
  required DateTime date,
  required String start,
  required String end,
  String status = 'AGENDADA',
}) {
  expect(entry.date, date);
  expect(entry.startTime, start);
  expect(entry.endTime, end);
  expect(entry.status, status);
}

void main() {
  group('las consultas agendadas de ejemplo salen del reloj', () {
    test(
      'a las 19:30: la 9001 a las 20:30 y la 9004 a las 22:30, de hoy',
      () async {
        final entries = await _entries(_repository(_at(2026, 11, 17, 19, 30)));

        _expectEntry(
          entries[9001]!,
          date: DateTime.utc(2026, 11, 17),
          start: '20:30',
          end: '20:50',
        );
        _expectEntry(
          entries[9004]!,
          date: DateTime.utc(2026, 11, 17),
          start: '22:30',
          end: '22:50',
        );
      },
    );

    test('las horas se redondean hacia arriba a múltiplos de 5 minutos', () async {
      // 10:07:30 más 1 hora son las 11:07:30 y se pasa a 11:10; más 3, a 13:10.
      final entries = await _entries(_repository(_at(2026, 11, 17, 10, 7, 30)));

      _expectEntry(
        entries[9001]!,
        date: DateTime.utc(2026, 11, 17),
        start: '11:10',
        end: '11:30',
      );
      _expectEntry(
        entries[9004]!,
        date: DateTime.utc(2026, 11, 17),
        start: '13:10',
        end: '13:30',
      );
    });

    test('con segundos nunca empieza antes de la hora pedida', () async {
      // 10:05:30 más 1 hora son las 11:05:30: no puede quedar en 11:05.
      final entries = await _entries(_repository(_at(2026, 11, 17, 10, 5, 30)));

      expect(entries[9001]!.startTime, '11:10');
      expect(entries[9004]!.startTime, '13:10');
    });

    test('una hora que ya es múltiplo de 5 no se corre', () async {
      final entries = await _entries(_repository(_at(2026, 11, 17, 8, 15)));

      expect(entries[9001]!.startTime, '09:15');
      expect(entries[9004]!.startTime, '11:15');
    });

    test('cerca de medianoche la 9004 pasa al día siguiente', () async {
      // 22:40: la 9001 a las 23:40 de hoy; la 9004 a las 01:40 de mañana.
      final entries = await _entries(_repository(_at(2026, 11, 17, 22, 40)));

      _expectEntry(
        entries[9001]!,
        date: DateTime.utc(2026, 11, 17),
        start: '23:40',
        end: '23:59',
      );
      _expectEntry(
        entries[9004]!,
        date: DateTime.utc(2026, 11, 18),
        start: '01:40',
        end: '02:00',
      );
    });

    test('a las 23:58 las dos son de mañana (00:58 y 02:58 se redondean a 01:00 y 03:00)', () async {
      final entries = await _entries(_repository(_at(2026, 11, 17, 23, 58)));

      _expectEntry(
        entries[9001]!,
        date: DateTime.utc(2026, 11, 18),
        start: '01:00',
        end: '01:20',
      );
      _expectEntry(
        entries[9004]!,
        date: DateTime.utc(2026, 11, 18),
        start: '03:00',
        end: '03:20',
      );
    });

    test('si la 9001 cae a las 23:55 termina a las 23:59', () async {
      final entries = await _entries(_repository(_at(2026, 11, 17, 22, 55)));

      _expectEntry(
        entries[9001]!,
        date: DateTime.utc(2026, 11, 17),
        start: '23:55',
        end: '23:59',
      );
    });

    test('el día de hoy es el de Uruguay, no el del reloj en UTC', () async {
      // 21:30 en Uruguay es 00:30 UTC del día siguiente.
      final entries = await _entries(_repository(_at(2026, 11, 17, 21, 30)));

      expect(entries[9002]!.date, DateTime.utc(2026, 11, 17));
      expect(entries[9001]!.date, DateTime.utc(2026, 11, 17));
    });

    test('las otras tres consultas no cambian con la hora', () async {
      for (final now in [_at(2026, 11, 17, 3, 0), _at(2026, 11, 17, 19, 30)]) {
        final entries = await _entries(_repository(now));

        _expectEntry(
          entries[9002]!,
          date: DateTime.utc(2026, 11, 17),
          start: '09:20',
          end: '09:40',
          status: 'NO_ATENDIDA',
        );
        _expectEntry(
          entries[9003]!,
          date: DateTime.utc(2026, 11, 17),
          start: '10:00',
          end: '10:30',
          status: 'ATENDIDA',
        );
        _expectEntry(
          entries[9005]!,
          date: DateTime.utc(2026, 11, 17),
          start: '15:00',
          end: '15:30',
          status: 'CANCELADA_SOCIO',
        );
        expect(entries.keys.toSet(), {9001, 9002, 9003, 9004, 9005});
      }
    });

    test('la 9001 y la 9004 conservan socio, médico y consultorio', () async {
      final entries = await _entries(_repository(_at(2026, 11, 17, 19, 30)));

      expect(entries[9001]!.member.ci, '90000046');
      expect(entries[9001]!.member.fullName, 'Ana Fernández');
      expect(entries[9001]!.doctor.id, 4);
      expect(entries[9001]!.clinic.name, 'Consultorio 3');
      expect(entries[9004]!.member.fullName, 'Laura Gómez');
      expect(entries[9004]!.doctor.id, 6);
      expect(entries[9004]!.clinic.name, 'Consultorio 7');
    });

    test('las consultas de llegada no quedan en el futuro', () async {
      final entries = await _entries(_repository(_at(2026, 11, 17, 19, 30)));

      expect(entries[9001]!.arrivedAt, isNull);
      expect(entries[9004]!.arrivedAt, isNull);
    });
  });

  group('a cualquier hora hay una cancelable y una que no', () {
    test(
      'la 9001 siempre da fuera de plazo y la 9004 siempre se cancela',
      () async {
        for (var hour = 0; hour < 24; hour++) {
          for (final minute in [0, 7, 30, 59]) {
            final now = _at(2026, 11, 17, hour, minute);
            final schedules = _repository(now);
            final cancellation = FakeStaffCancellationRepository(
              schedules,
              latency: Duration.zero,
              clock: () => now,
            );
            final hora = '$hour:$minute';

            await expectLater(
              cancellation.cancel(9001),
              throwsA(
                isA<StaffCancellationException>().having(
                  (e) => e.failure,
                  'failure',
                  StaffCancellationFailure.outsideWindow,
                ),
              ),
              reason: 'la 9001 a las $hora',
            );
            expect(schedules.findById(9001)!.status, 'AGENDADA', reason: hora);

            final result = await cancellation.cancel(9004);
            expect(
              result.status,
              'CANCELADA_SOCIO',
              reason: 'la 9004 a las $hora',
            );
            expect(
              schedules.findById(9004)!.status,
              'CANCELADA_SOCIO',
              reason: hora,
            );
          }
        }
      },
    );
  });

  group('en la app con USE_FAKES', () {
    ProviderContainer containerAt(DateTime now) {
      final container = ProviderContainer(
        overrides: [
          useFakesProvider.overrideWithValue(true),
          schedulesClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('el reloj de agendas es el real salvo que se sobrescriba', () {
      final before = DateTime.now();
      final value = ProviderContainer().read(schedulesClockProvider)();
      final after = DateTime.now();

      expect(value.isBefore(before), isFalse);
      expect(value.isAfter(after), isFalse);
    });

    test(
      'el repositorio de agendas se arma con el reloj del proveedor',
      () async {
        final container = containerAt(_at(2026, 11, 17, 19, 30));
        final repository = await container.read(
          scheduleRepositoryProvider.future,
        ) as FakeScheduleRepository;

        final entries = await _entries(repository);
        expect(entries[9001]!.startTime, '20:30');
        expect(entries[9004]!.startTime, '22:30');
      },
    );

    test('la cancelación usa el mismo reloj: 9001 no, 9004 sí (un reloj lejos de la hora real)', () async {
      final container = containerAt(_at(2030, 6, 15, 8, 0));
      final cancellation = await container.read(
        staffCancellationRepositoryProvider.future,
      );

      await expectLater(
        cancellation.cancel(9001),
        throwsA(isA<StaffCancellationException>()),
      );
      expect((await cancellation.cancel(9004)).status, 'CANCELADA_SOCIO');
    });
  });
}
