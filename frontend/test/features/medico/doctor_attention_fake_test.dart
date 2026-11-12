import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_attention_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = FakeDoctorAttentionRepository(latency: Duration.zero);
  DoctorAttentionQuery query({
    DoctorAttentionOrder order = DoctorAttentionOrder.date,
    DoctorAttentionDirection direction = DoctorAttentionDirection.descending,
    String patient = '',
    int? specialty,
  }) => DoctorAttentionQuery(
    from: DateTime.utc(2026, 9, 1),
    to: DateTime.utc(2026, 10, 31),
    order: order,
    direction: direction,
    patientText: patient,
    specialtyId: specialty,
  );
  test('ordena con los desempates del contrato', () async {
    Future<List<int>> ids(DoctorAttentionQuery q) async =>
        (await repo.list(q)).map((a) => a.id).toList();
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
    final day = DoctorAttentionQuery(
      from: DateTime.utc(2026, 10, 14),
      to: DateTime.utc(2026, 10, 14),
    );
    expect(await ids(day), [5531]);
  });
  test('detalle y errores', () async {
    expect(
      (await repo.get(5530)).referrals.single.expiresOn,
      DateTime.utc(2027, 1, 18),
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
