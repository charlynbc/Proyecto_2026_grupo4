import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_attention_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Con este reloj fijo son las 12:00 del 12/11/2026 en Uruguay. Las fechas de
// las atenciones falsas, escritas a mano:
//   5530 Lucía Fernández, Cardiología:        12/11/2026 (hoy), pase hasta 10/02/2027
//   5533 Ana Pérez, Medicina General:         12/11/2026 (hoy)
//   5531 Bruno Acosta, Medicina General:      09/11/2026 (hoy menos 3 días)
//   5532 Lucía Fernández, Cardiología:        03/10/2026 (hoy menos 40 días)
// El período por defecto de la pantalla va del 01/11/2026 al 12/11/2026.
DateTime fixedClock() => DateTime.utc(2026, 11, 12, 15);

void main() {
  final repo = FakeDoctorAttentionRepository(
    latency: Duration.zero,
    clock: fixedClock,
  );
  DoctorAttentionQuery query({
    DoctorAttentionOrder order = DoctorAttentionOrder.date,
    DoctorAttentionDirection direction = DoctorAttentionDirection.descending,
    String patient = '',
    int? specialty,
  }) => DoctorAttentionQuery(
    from: DateTime.utc(2026, 10, 1),
    to: DateTime.utc(2026, 11, 30),
    order: order,
    direction: direction,
    patientText: patient,
    specialtyId: specialty,
  );
  DoctorAttentionQuery period(DateTime from, DateTime to) =>
      DoctorAttentionQuery(from: from, to: to);
  Future<List<int>> ids(DoctorAttentionQuery q) async =>
      (await repo.list(q)).map((a) => a.id).toList();

  test('las fechas son relativas a hoy', () async {
    expect((await repo.get(5530)).attendedOn, DateTime.utc(2026, 11, 12));
    expect((await repo.get(5533)).attendedOn, DateTime.utc(2026, 11, 12));
    expect((await repo.get(5531)).attendedOn, DateTime.utc(2026, 11, 9));
    expect((await repo.get(5532)).attendedOn, DateTime.utc(2026, 10, 3));
  });

  test('el período por defecto trae las tres atenciones recientes', () async {
    final result = await ids(
      period(DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 12)),
    );
    expect(result, [5533, 5530, 5531]);
    expect(result, isNot(contains(5532)));
  });

  test('los límites del período son inclusivos', () async {
    expect(
      await ids(period(DateTime.utc(2026, 11, 12), DateTime.utc(2026, 11, 12))),
      [5533, 5530],
    );
    expect(
      await ids(period(DateTime.utc(2026, 11, 9), DateTime.utc(2026, 11, 9))),
      [5531],
    );
    expect(
      await ids(period(DateTime.utc(2026, 10, 3), DateTime.utc(2026, 10, 3))),
      [5532],
    );
    expect(
      await ids(period(DateTime.utc(2026, 11, 10), DateTime.utc(2026, 11, 11))),
      isEmpty,
    );
    expect(
      await ids(period(DateTime.utc(2026, 11, 13), DateTime.utc(2026, 11, 30))),
      isEmpty,
    );
    expect(
      await ids(period(DateTime.utc(2026, 10, 4), DateTime.utc(2026, 11, 8))),
      isEmpty,
    );
  });

  test(
    'con el período por defecto cada filtro da un resultado distinto',
    () async {
      DoctorAttentionQuery inPeriod({String patient = '', int? specialty}) =>
          DoctorAttentionQuery(
            from: DateTime.utc(2026, 11, 1),
            to: DateTime.utc(2026, 11, 12),
            patientText: patient,
            specialtyId: specialty,
          );
      expect(await ids(inPeriod(patient: 'fern')), [5530]);
      expect(await ids(inPeriod(patient: '5.012.345-6')), [5531]);
      expect(await ids(inPeriod(patient: 'pérez')), [5533]);
      expect(await ids(inPeriod(specialty: 3)), [5530]);
      expect(await ids(inPeriod(specialty: 1)), [5533, 5531]);
    },
  );

  test('ordena con los desempates del contrato', () async {
    expect(await ids(query()), [5533, 5530, 5531, 5532]);
    expect(await ids(query(direction: DoctorAttentionDirection.ascending)), [
      5532,
      5531,
      5530,
      5533,
    ]);
    expect(
      await ids(
        query(
          order: DoctorAttentionOrder.patientLastName,
          direction: DoctorAttentionDirection.ascending,
        ),
      ),
      [5531, 5530, 5532, 5533],
    );
    expect(await ids(query(order: DoctorAttentionOrder.patientLastName)), [
      5533,
      5530,
      5532,
      5531,
    ]);
    expect(await ids(query(patient: 'fern')), [5530, 5532]);
    expect(await ids(query(patient: '5.012.345-6')), [5531]);
    expect(await ids(query(specialty: 3)), [5530, 5532]);
  });

  test('hoy se calcula en hora de Uruguay, no en UTC', () async {
    // 02:00 UTC del 13/11 son las 23:00 del 12/11 en Uruguay.
    final lateNight = FakeDoctorAttentionRepository(
      latency: Duration.zero,
      clock: () => DateTime.utc(2026, 11, 13, 2),
    );
    expect((await lateNight.get(5530)).attendedOn, DateTime.utc(2026, 11, 12));
    // 03:00 UTC del 13/11 ya es medianoche del 13/11 en Uruguay.
    final midnight = FakeDoctorAttentionRepository(
      latency: Duration.zero,
      clock: () => DateTime.utc(2026, 11, 13, 3),
    );
    expect((await midnight.get(5530)).attendedOn, DateTime.utc(2026, 11, 13));
    expect((await midnight.get(5531)).attendedOn, DateTime.utc(2026, 11, 10));
    expect((await midnight.get(5532)).attendedOn, DateTime.utc(2026, 10, 4));
  });

  test('con el reloj real el período por defecto no abre vacío', () async {
    final real = FakeDoctorAttentionRepository(latency: Duration.zero);
    final result = await real.list(DoctorAttentionQuery.initial());
    expect(result, isNotEmpty);
  });

  test('detalle y errores', () async {
    expect(
      (await repo.get(5530)).referrals.single.expiresOn,
      DateTime.utc(2027, 2, 10),
    );
    expect(
      () => repo.get(1),
      throwsA(
        isA<DoctorAttentionException>().having(
          (e) => e.failure,
          'failure',
          DoctorAttentionFailure.notFound,
        ),
      ),
    );
    expect(
      () => repo.get(0),
      throwsA(
        isA<DoctorAttentionException>().having(
          (e) => e.failure,
          'failure',
          DoctorAttentionFailure.validation,
        ),
      ),
    );
  });
}
