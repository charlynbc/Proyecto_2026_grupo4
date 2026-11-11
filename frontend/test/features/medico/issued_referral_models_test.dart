import 'package:agenda_medica/features/medico/models/issued_referral.dart';
import 'package:agenda_medica/features/medico/models/issued_referral_query.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({String status = 'DISPONIBLE'}) => {
  'id': 78,
  'paciente': {
    'id': 21,
    'ci': '45678911',
    'nombre': 'Lucía',
    'apellido': 'Fernández',
  },
  'especialidadDestino': {'id': 4, 'nombre': 'Nutrición', 'requierePase': true},
  'emitidoEn': '2026-10-20T09:41:00-03:00',
  'venceEl': '2027-01-18',
  'situacion': status,
};

void main() {
  group('IssuedReferral.fromJson', () {
    test('lee el pase del contrato', () {
      final referral = IssuedReferral.fromJson(_json());

      expect(referral.id, 78);
      expect(referral.patient.id, 21);
      expect(referral.patient.ci, '45678911');
      expect(referral.patient.name, 'Lucía');
      expect(referral.patient.lastName, 'Fernández');
      expect(referral.patient.fullName, 'Lucía Fernández');
      expect(referral.destination.id, 4);
      expect(referral.destination.name, 'Nutrición');
      expect(referral.destination.requiresReferral, isTrue);
      expect(referral.issuedAt, DateTime.utc(2026, 10, 20, 12, 41));
      expect(referral.expiresOn, DateTime.utc(2027, 1, 18));
      expect(referral.status, ReferralStatus.available);
    });

    test('UTILIZADO y VENCIDO', () {
      expect(
        IssuedReferral.fromJson(_json(status: 'UTILIZADO')).status,
        ReferralStatus.used,
      );
      expect(
        IssuedReferral.fromJson(_json(status: 'VENCIDO')).status,
        ReferralStatus.expired,
      );
    });

    test('una situación desconocida lanza FormatException', () {
      expect(
        () => IssuedReferral.fromJson(_json(status: 'ANULADO')),
        throwsFormatException,
      );
    });
  });

  group('ReferralStatus', () {
    test('valores de la API y textos', () {
      expect(ReferralStatus.available.apiValue, 'DISPONIBLE');
      expect(ReferralStatus.used.apiValue, 'UTILIZADO');
      expect(ReferralStatus.expired.apiValue, 'VENCIDO');
      expect(ReferralStatus.available.label, 'Disponible');
      expect(ReferralStatus.used.label, 'Utilizado');
      expect(ReferralStatus.expired.label, 'Vencido');
    });

    test('fromApi con otro valor lanza FormatException', () {
      expect(() => ReferralStatus.fromApi('ANULADO'), throwsFormatException);
    });
  });

  group('IssuedReferralQuery.toQueryParameters', () {
    test('por defecto: vencimiento y ascendente, sin situación', () {
      expect(const IssuedReferralQuery().toQueryParameters(), {
        'orden': 'vencimiento',
        'sentido': 'asc',
      });
    });

    test('con situación, emisión y descendente', () {
      const query = IssuedReferralQuery(
        status: ReferralStatus.used,
        order: IssuedReferralOrder.issue,
        direction: IssuedReferralDirection.descending,
      );

      expect(query.toQueryParameters(), {
        'situacion': 'UTILIZADO',
        'orden': 'emision',
        'sentido': 'desc',
      });
    });
  });
}
