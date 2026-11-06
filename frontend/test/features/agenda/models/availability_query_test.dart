import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvailabilityQuery', () {
    test('sin especialidad omite especialidadId y manda el médico', () {
      const query = AvailabilityQuery(doctorId: 4);

      expect(query.toQueryParameters(), {
        'medicoId': 4,
        'orden': 'fecha',
        'sentido': 'asc',
      });
      expect(query.toQueryParameters().containsKey('especialidadId'), isFalse);
    });

    test('sin médico omite medicoId y manda la especialidad', () {
      const query = AvailabilityQuery(specialtyId: 2);

      expect(query.toQueryParameters(), {
        'especialidadId': 2,
        'orden': 'fecha',
        'sentido': 'asc',
      });
    });

    test('con los dos manda ambos y las fechas como YYYY-MM-DD', () {
      final query = AvailabilityQuery(
        specialtyId: 2,
        doctorId: 4,
        from: DateTime.utc(2026, 11, 1),
        to: DateTime.utc(2026, 11, 30),
        order: AvailabilityOrder.doctorLastName,
        direction: SortDirection.desc,
      );

      expect(query.toQueryParameters(), {
        'especialidadId': 2,
        'medicoId': 4,
        'fechaDesde': '2026-11-01',
        'fechaHasta': '2026-11-30',
        'orden': 'apellidoMedico',
        'sentido': 'desc',
      });
    });

    test('exige al menos la especialidad o el médico', () {
      expect(() => AvailabilityQuery(), throwsAssertionError);
    });

    test('las consultas solo con médico son iguales por valor', () {
      expect(
        const AvailabilityQuery(doctorId: 4),
        const AvailabilityQuery(doctorId: 4),
      );
      expect(
        const AvailabilityQuery(doctorId: 4).hashCode,
        const AvailabilityQuery(doctorId: 4).hashCode,
      );
      expect(
        const AvailabilityQuery(doctorId: 4),
        isNot(const AvailabilityQuery(specialtyId: 4)),
      );
    });

    test('withOrder y withRange conservan que no hay especialidad', () {
      final query = const AvailabilityQuery(doctorId: 4)
          .withOrder(direction: SortDirection.desc)
          .withRange(from: DateTime.utc(2026, 11, 1));

      expect(query.specialtyId, isNull);
      expect(query.doctorId, 4);
      expect(query.direction, SortDirection.desc);
      expect(query.from, DateTime.utc(2026, 11, 1));
    });
  });
}
