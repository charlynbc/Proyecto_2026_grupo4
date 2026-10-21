import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_numbers_rules.dart';

ShiftNumber n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

void main() {
  group('ShiftNumber', () {
    test('formatea y calcula la duración', () {
      final number = n(1, '09:05', '09:25');
      expect(number.duration, 20);
      expect(ShiftNumber.formatTime(number.startMinutes), '09:05');
      expect(ShiftNumber.formatTime(number.endMinutes), '09:25');
    });

    test('toJson usa HH:mm', () {
      expect(n(2, '10:00', '10:30').toJson(), {
        'numero': 2,
        'horaInicio': '10:00',
        'horaFin': '10:30',
      });
    });
  });

  group('validateNumbers', () {
    test('una lista válida no tiene errores, aunque haya huecos', () {
      expect(
        validateNumbers([
          n(1, '09:00', '09:20'),
          n(2, '09:20', '09:40'),
          n(3, '10:00', '10:30'),
        ]),
        isEmpty,
      );
    });

    test('pide al menos un número', () {
      expect(validateNumbers([]), [contains('al menos un número')]);
    });

    test('rechaza duraciones menores a 10 minutos', () {
      final errors = validateNumbers([n(1, '09:00', '09:05')]);
      expect(errors, [contains('entre 10 y 60 minutos')]);
    });

    test('acepta exactamente 10 y 60 minutos', () {
      expect(
        validateNumbers([n(1, '09:00', '09:10'), n(2, '10:00', '11:00')]),
        isEmpty,
      );
    });

    test('rechaza duraciones mayores a 60 minutos', () {
      final errors = validateNumbers([n(1, '09:00', '10:05')]);
      expect(errors, [contains('entre 10 y 60 minutos')]);
    });

    test('rechaza un fin anterior o igual al inicio', () {
      expect(validateNumbers([n(1, '10:00', '09:30')]), [
        contains('posterior'),
      ]);
      expect(validateNumbers([n(1, '10:00', '10:00')]), [
        contains('posterior'),
      ]);
    });

    test('rechaza horas que no son múltiplos de 5', () {
      final errors = validateNumbers([n(1, '09:07', '09:27')]);
      expect(errors, [contains('múltiplos de 5')]);
    });

    test('rechaza números que se solapan, estén o no en orden', () {
      final errors = validateNumbers([
        n(1, '09:00', '09:30'),
        n(2, '09:20', '09:40'),
      ]);
      expect(errors, [contains('se solapan')]);
      final unordered = validateNumbers([
        n(1, '09:20', '09:40'),
        n(2, '09:00', '09:30'),
      ]);
      expect(unordered, [contains('se solapan')]);
    });

    test('números que se tocan en un extremo no se solapan', () {
      expect(
        validateNumbers([n(1, '09:00', '09:20'), n(2, '09:20', '09:40')]),
        isEmpty,
      );
    });
  });

  // El invariante en el que se apoya la validación: se compara cada número
  // con el siguiente después de ordenar por inicio, así que el orden en que
  // vengan no puede esconder un solapamiento. Los dos primeros tests lo
  // documentan pero pasan también sin ordenar (un chequeo de vecinos sin
  // ordenar solo puede marcar de más, no dejar pasar); el que protege el sort
  // es el tercero, que sin ordenar da un error falso con números separados.
  group('validateNumbers no depende del orden de la lista', () {
    final overlapping = [
      n(1, '09:30', '09:50'),
      n(2, '09:00', '10:00'),
      n(3, '09:10', '09:20'),
    ];

    List<List<ShiftNumber>> permutations(List<ShiftNumber> items) {
      if (items.length <= 1) return [items];
      return [
        for (var i = 0; i < items.length; i++)
          for (final rest in permutations([
            ...items.sublist(0, i),
            ...items.sublist(i + 1),
          ]))
            [items[i], ...rest],
      ];
    }

    test('el caso 09:30-09:50, 09:00-10:00 y 09:10-09:20 se avisa', () {
      final errors = validateNumbers(overlapping);

      expect(errors, isNotEmpty);
      expect(errors, everyElement(contains('se solapan')));
    });

    test('las seis formas de ordenarlos avisan el solapamiento', () {
      final all = permutations(overlapping);
      expect(all, hasLength(6));

      for (final order in all) {
        expect(
          validateNumbers(order),
          isNotEmpty,
          reason: order.map((e) => e.number).join(','),
        );
      }
    });

    test('sin solapamientos, ninguna forma de ordenarlos da error', () {
      final apart = [
        n(1, '10:00', '10:20'),
        n(2, '08:00', '08:20'),
        n(3, '09:00', '09:20'),
      ];

      for (final order in permutations(apart)) {
        expect(validateNumbers(order), isEmpty);
      }
    });
  });

  group('sortNumbers', () {
    test('ordena por hora de inicio y no renumera', () {
      final sorted = sortNumbers([
        n(1, '10:00', '10:20'),
        n(2, '08:00', '08:20'),
        n(3, '09:00', '09:20'),
      ]);

      expect(sorted.map((e) => e.startMinutes), [8 * 60, 9 * 60, 10 * 60]);
      expect(sorted.map((e) => e.number), [2, 3, 1]);
    });

    test('con el mismo inicio, desempata por la hora de fin', () {
      final sorted = sortNumbers([
        n(1, '09:00', '09:40'),
        n(2, '09:00', '09:20'),
      ]);

      expect(sorted.map((e) => e.endMinutes), [9 * 60 + 20, 9 * 60 + 40]);
    });

    test('devuelve una lista nueva y deja la original como estaba', () {
      final original = [n(1, '10:00', '10:20'), n(2, '08:00', '08:20')];

      final sorted = sortNumbers(original);

      expect(identical(sorted, original), isFalse);
      expect(original.map((e) => e.number), [1, 2]);
    });

    test('una lista vacía o de un número queda igual', () {
      expect(sortNumbers(const []), isEmpty);
      expect(sortNumbers([n(1, '09:00', '09:20')]).single.number, 1);
    });
  });

  group('latestEnd', () {
    test('es la hora de fin más tarde, en cualquier orden', () {
      expect(
        latestEnd([
          n(1, '09:00', '09:20'),
          n(2, '09:10', '09:50'),
          n(3, '08:00', '08:40'),
        ]),
        9 * 60 + 50,
      );
    });

    test('puede no ser la del número que empieza último', () {
      // 09:10-09:20 empieza después, pero 09:00-10:00 termina más tarde.
      expect(
        latestEnd([n(1, '09:00', '10:00'), n(2, '09:10', '09:20')]),
        10 * 60,
      );
    });

    test('sin números no hay hora de fin', () {
      expect(latestEnd(const []), isNull);
    });
  });

  group('generateConsecutive', () {
    test('genera números seguidos con la duración elegida', () {
      final result = generateConsecutive(
        startMinutes: ShiftNumber.parseTime('09:00'),
        endMinutes: ShiftNumber.parseTime('10:00'),
        durationMinutes: 20,
        firstNumber: 1,
      );
      expect(result.numbers.map((e) => e.toJson()).toList(), [
        {'numero': 1, 'horaInicio': '09:00', 'horaFin': '09:20'},
        {'numero': 2, 'horaInicio': '09:20', 'horaFin': '09:40'},
        {'numero': 3, 'horaInicio': '09:40', 'horaFin': '10:00'},
      ]);
      expect(result.leftoverMinutes, 0);
    });

    test('omite el último si no entra y avisa cuánto sobró', () {
      final result = generateConsecutive(
        startMinutes: ShiftNumber.parseTime('09:00'),
        endMinutes: ShiftNumber.parseTime('10:00'),
        durationMinutes: 25,
        firstNumber: 4,
      );
      expect(result.numbers.length, 2);
      expect(result.numbers.first.number, 4);
      expect(result.leftoverMinutes, 10);
    });

    test('todo lo generado cumple las reglas y son múltiplos de 5', () {
      for (final duration in kDurationOptions) {
        final result = generateConsecutive(
          startMinutes: ShiftNumber.parseTime('08:00'),
          endMinutes: ShiftNumber.parseTime('12:00'),
          durationMinutes: duration,
          firstNumber: 1,
        );
        expect(validateNumbers(result.numbers), isEmpty, reason: '$duration');
        for (final number in result.numbers) {
          expect(number.startMinutes % 5, 0);
          expect(number.endMinutes % 5, 0);
        }
      }
    });

    test('una duración de cero o negativa es un error de programación', () {
      for (final duration in [0, -5]) {
        expect(
          () => generateConsecutive(
            startMinutes: ShiftNumber.parseTime('09:00'),
            endMinutes: ShiftNumber.parseTime('10:00'),
            durationMinutes: duration,
            firstNumber: 1,
          ),
          throwsAssertionError,
          reason: '$duration',
        );
      }
    });

    test('las duraciones elegibles son múltiplos de 5 entre 10 y 60', () {
      expect(kDurationOptions.first, 10);
      expect(kDurationOptions.last, 60);
      expect(kDurationOptions.every((d) => d % 5 == 0), isTrue);
    });
  });

  group('omitCoveredNumbers', () {
    ShiftNumber g(String start, String end) => n(1, start, end);

    test('omite un número idéntico a uno existente', () {
      final result = omitCoveredNumbers(
        existing: [n(1, '09:00', '09:20')],
        generated: [g('09:00', '09:20'), g('09:20', '09:40')],
      );
      expect(result.omitted, 1);
      expect(result.kept.map((e) => e.startMinutes), [
        ShiftNumber.parseTime('09:20'),
      ]);
    });

    test('omite un número contenido en uno existente', () {
      final result = omitCoveredNumbers(
        existing: [n(1, '09:00', '09:40')],
        generated: [g('09:10', '09:30')],
      );
      expect(result.omitted, 1);
      expect(result.kept, isEmpty);
    });

    test('conserva un solapamiento parcial', () {
      final result = omitCoveredNumbers(
        existing: [n(1, '09:10', '09:30')],
        generated: [g('09:00', '09:20'), g('09:20', '09:40')],
      );
      expect(result.omitted, 0);
      expect(result.kept.length, 2);
    });

    test('conserva un generado que contiene a uno existente', () {
      final result = omitCoveredNumbers(
        existing: [n(1, '09:05', '09:15')],
        generated: [g('09:00', '09:20')],
      );
      expect(result.omitted, 0);
      expect(result.kept.length, 1);
    });

    test('los extremos que se tocan no cuentan como contenidos', () {
      final result = omitCoveredNumbers(
        existing: [n(1, '09:00', '09:20')],
        generated: [g('09:20', '09:40')],
      );
      expect(result.omitted, 0);
    });

    test('cubierto solo por la suma de dos existentes, se conserva', () {
      // 09:10-09:30 queda tapado por 09:00-09:20 más 09:20-09:40, pero no
      // completo dentro de ninguno de los dos: no es un duplicado.
      final result = omitCoveredNumbers(
        existing: [n(1, '09:00', '09:20'), n(2, '09:20', '09:40')],
        generated: [g('09:10', '09:30')],
      );
      expect(result.omitted, 0);
      expect(result.kept.length, 1);
    });

    test('con el mismo inicio que el existente y menos largo, se omite', () {
      final result = omitCoveredNumbers(
        existing: [n(1, '09:00', '09:40')],
        generated: [g('09:00', '09:20')],
      );
      expect(result.omitted, 1);
      expect(result.kept, isEmpty);
    });

    test('con el mismo final que el existente y menos largo, se omite', () {
      final result = omitCoveredNumbers(
        existing: [n(1, '09:00', '09:40')],
        generated: [g('09:20', '09:40')],
      );
      expect(result.omitted, 1);
      expect(result.kept, isEmpty);
    });

    test('sin números cargados no omite nada', () {
      final result = omitCoveredNumbers(
        existing: [],
        generated: [g('09:00', '09:20')],
      );
      expect(result.omitted, 0);
      expect(result.kept.length, 1);
    });

    test('conserva el orden y los datos de los que quedan', () {
      final result = omitCoveredNumbers(
        existing: [n(1, '09:20', '09:40')],
        generated: [
          n(7, '09:00', '09:20'),
          n(8, '09:20', '09:40'),
          n(9, '09:40', '10:00'),
        ],
      );
      expect(result.kept.map((e) => e.number), [7, 9]);
    });
  });

  group('countWeekdayDates', () {
    // 19/10/2026 es lunes.
    final monday = DateTime.utc(2026, 10, 19);

    test('cuenta las fechas del día elegido, extremos incluidos', () {
      expect(countWeekdayDates(monday, DateTime.utc(2026, 11, 2), 1), 3);
    });

    test('inicio igual a fin: 1 si coincide el día, 0 si no', () {
      expect(countWeekdayDates(monday, monday, 1), 1);
      expect(countWeekdayDates(monday, monday, 2), 0);
    });

    test('vigencia corta sin el día elegido da 0', () {
      // Miércoles 21 a viernes 23, buscando martes.
      expect(
        countWeekdayDates(
          DateTime.utc(2026, 10, 21),
          DateTime.utc(2026, 10, 23),
          2,
        ),
        0,
      );
    });

    test('1 es lunes y 7 es domingo', () {
      final sunday = DateTime.utc(2026, 10, 25);
      expect(countWeekdayDates(sunday, sunday, 7), 1);
      expect(countWeekdayDates(sunday, sunday, 1), 0);
    });

    test('un fin anterior al inicio da 0', () {
      expect(countWeekdayDates(DateTime.utc(2026, 10, 26), monday, 1), 0);
    });
  });

  group('weekdayDatesOf', () {
    test('lista las fechas en orden', () {
      expect(
        weekdayDatesOf(
          DateTime.utc(2026, 10, 19),
          DateTime.utc(2026, 11, 2),
          1,
        ),
        [
          DateTime.utc(2026, 10, 19),
          DateTime.utc(2026, 10, 26),
          DateTime.utc(2026, 11, 2),
        ],
      );
    });
  });
}
