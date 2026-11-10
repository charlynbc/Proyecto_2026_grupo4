import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/medico/models/issued_referral.dart';
import 'package:agenda_medica/features/medico/models/issued_referral_query.dart';
import 'package:agenda_medica/features/medico/repositories/fake_issued_referral_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> _ids(IssuedReferralQuery query) async {
  final list = await FakeIssuedReferralRepository(latency: Duration.zero)
      .list(query);
  return [for (final referral in list) referral.id];
}

void main() {
  group('orden', () {
    test('vencimiento ascendente', () async {
      expect(await _ids(const IssuedReferralQuery()), [80, 79, 78]);
    });

    test('vencimiento descendente', () async {
      expect(
        await _ids(
          const IssuedReferralQuery(
            direction: IssuedReferralDirection.descending,
          ),
        ),
        [78, 79, 80],
      );
    });

    test('emisión ascendente', () async {
      expect(
        await _ids(const IssuedReferralQuery(order: IssuedReferralOrder.issue)),
        [80, 79, 78],
      );
    });

    test('emisión descendente', () async {
      expect(
        await _ids(
          const IssuedReferralQuery(
            order: IssuedReferralOrder.issue,
            direction: IssuedReferralDirection.descending,
          ),
        ),
        [78, 79, 80],
      );
    });
  });

  group('situación', () {
    test('UTILIZADO', () async {
      expect(
        await _ids(const IssuedReferralQuery(status: ReferralStatus.used)),
        [79],
      );
    });

    test('VENCIDO', () async {
      expect(
        await _ids(const IssuedReferralQuery(status: ReferralStatus.expired)),
        [80],
      );
    });

    test('DISPONIBLE', () async {
      expect(
        await _ids(const IssuedReferralQuery(status: ReferralStatus.available)),
        [78],
      );
    });
  });

  group('con vencimiento y emisión en distinto orden', () {
    IssuedReferral referral(int id, DateTime issued, DateTime expires) =>
        IssuedReferral(
          id: id,
          patient: const IssuedReferralPatient(
            id: 1,
            ci: '1',
            name: 'A',
            lastName: 'B',
          ),
          destination: const Specialty(
            id: 1,
            name: 'X',
            requiresReferral: true,
          ),
          issuedAt: issued,
          expiresOn: expires,
          status: ReferralStatus.available,
        );

    // 1: emitido primero, vence último. 2: emitido segundo, vence primero.
    // 5 y 6 vencen el mismo día.
    final data = [
      referral(1, DateTime.utc(2026, 1, 1), DateTime.utc(2026, 12, 31)),
      referral(2, DateTime.utc(2026, 2, 1), DateTime.utc(2026, 3, 1)),
      referral(5, DateTime.utc(2026, 3, 1), DateTime.utc(2026, 6, 1)),
      referral(6, DateTime.utc(2026, 4, 1), DateTime.utc(2026, 6, 1)),
    ];

    Future<List<int>> ids(IssuedReferralQuery query) async {
      final list = await FakeIssuedReferralRepository(
        latency: Duration.zero,
        referrals: data,
      ).list(query);
      return [for (final r in list) r.id];
    }

    test('vencimiento ascendente: 2, 5, 6, 1 (desempate por id)', () async {
      expect(await ids(const IssuedReferralQuery()), [2, 5, 6, 1]);
    });

    test('vencimiento descendente: 1, 6, 5, 2 (desempate por id)', () async {
      expect(
        await ids(
          const IssuedReferralQuery(
            direction: IssuedReferralDirection.descending,
          ),
        ),
        [1, 6, 5, 2],
      );
    });

    test('emisión ascendente: 1, 2, 5, 6', () async {
      expect(
        await ids(const IssuedReferralQuery(order: IssuedReferralOrder.issue)),
        [1, 2, 5, 6],
      );
    });

    test('emisión descendente: 6, 5, 2, 1', () async {
      expect(
        await ids(
          const IssuedReferralQuery(
            order: IssuedReferralOrder.issue,
            direction: IssuedReferralDirection.descending,
          ),
        ),
        [6, 5, 2, 1],
      );
    });
  });

  test('los datos del pase 78', () async {
    final list = await FakeIssuedReferralRepository(latency: Duration.zero)
        .list(const IssuedReferralQuery(status: ReferralStatus.available));

    final referral = list.single;
    expect(referral.patient.id, 21);
    expect(referral.patient.ci, '45678911');
    expect(referral.patient.fullName, 'Lucía Fernández');
    expect(referral.destination.id, 4);
    expect(referral.destination.name, 'Nutrición');
    expect(referral.issuedAt, DateTime.utc(2026, 10, 20, 12, 41));
    expect(referral.expiresOn, DateTime.utc(2027, 1, 18));
  });
}
