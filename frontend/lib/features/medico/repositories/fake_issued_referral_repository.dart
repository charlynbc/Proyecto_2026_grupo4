import '../../especialidades/models/specialty.dart';
import '../models/issued_referral.dart';
import '../models/issued_referral_query.dart';
import 'issued_referral_repository.dart';

/// Implementación en memoria de [IssuedReferralRepository] para
/// `USE_FAKES=true`. Filtra y ordena como el servidor (el desempate es por id,
/// en el mismo sentido).
///
/// La situación de cada pase es fija en los datos: este fake no sigue las
/// cancelaciones de consultas (RF-27), que en el servidor devuelven un pase
/// utilizado a disponible.
class FakeIssuedReferralRepository implements IssuedReferralRepository {
  FakeIssuedReferralRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;

  static final List<IssuedReferral> _referrals = [
    IssuedReferral(
      id: 78,
      patient: const IssuedReferralPatient(
        id: 21,
        ci: '45678911',
        name: 'Lucía',
        lastName: 'Fernández',
      ),
      destination: const Specialty(
        id: 4,
        name: 'Nutrición',
        requiresReferral: true,
      ),
      issuedAt: DateTime.parse('2026-10-20T09:41:00-03:00'),
      expiresOn: DateTime.utc(2027, 1, 18),
      status: ReferralStatus.available,
    ),
    IssuedReferral(
      id: 79,
      patient: const IssuedReferralPatient(
        id: 22,
        ci: '50123456',
        name: 'Bruno',
        lastName: 'Acosta',
      ),
      destination: const Specialty(
        id: 3,
        name: 'Cardiología',
        requiresReferral: true,
      ),
      issuedAt: DateTime.parse('2026-09-10T15:05:00-03:00'),
      expiresOn: DateTime.utc(2026, 12, 9),
      status: ReferralStatus.used,
    ),
    IssuedReferral(
      id: 80,
      patient: const IssuedReferralPatient(
        id: 23,
        ci: '11111111',
        name: 'Ana',
        lastName: 'Pérez',
      ),
      destination: const Specialty(
        id: 2,
        name: 'Dermatología',
        requiresReferral: true,
      ),
      issuedAt: DateTime.parse('2026-06-01T10:00:00-03:00'),
      expiresOn: DateTime.utc(2026, 8, 30),
      status: ReferralStatus.expired,
    ),
  ];

  @override
  Future<List<IssuedReferral>> list(IssuedReferralQuery query) async {
    await Future<void>.delayed(latency);
    final result = [
      for (final referral in _referrals)
        if (query.status == null || referral.status == query.status) referral,
    ];
    final sign = query.direction == IssuedReferralDirection.ascending ? 1 : -1;
    result.sort((a, b) {
      final byDate = switch (query.order) {
        IssuedReferralOrder.expiry => a.expiresOn.compareTo(b.expiresOn),
        IssuedReferralOrder.issue => a.issuedAt.compareTo(b.issuedAt),
      };
      return sign * (byDate != 0 ? byDate : a.id.compareTo(b.id));
    });
    return result;
  }
}
