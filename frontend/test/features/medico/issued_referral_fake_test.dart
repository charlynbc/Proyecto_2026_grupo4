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
