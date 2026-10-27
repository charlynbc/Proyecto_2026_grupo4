import 'package:agenda_medica/features/agenda/models/referral.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un pase como lo manda `GET /api/socios/me/pases/disponibles`. La
/// especialidad es Cardiología, la del catálogo de los fakes (id 2).
Map<String, dynamic> _json() => {
  'id': 77,
  'especialidadDestino': {
    'id': 2,
    'nombre': 'Cardiología',
    'requierePase': true,
  },
  'emitidoEn': '2026-10-20T14:30:00Z',
  'venceEl': '2026-11-19',
};

void main() {
  group('Referral.fromJson', () {
    test('lee los cuatro campos', () {
      final referral = Referral.fromJson(_json());

      expect(referral.id, 77);
      expect(referral.specialty.id, 2);
      expect(referral.specialty.name, 'Cardiología');
      expect(referral.specialty.requiresReferral, isTrue);
      expect(referral.issuedAt, DateTime.utc(2026, 10, 20, 14, 30));
      expect(referral.expiresOn, DateTime.utc(2026, 11, 19));
    });

    test('emitidoEn con -03:00 es el mismo instante que con Z', () {
      final withOffset = Referral.fromJson(
        _json()..['emitidoEn'] = '2026-10-20T11:30:00-03:00',
      );
      final withZ = Referral.fromJson(_json());

      expect(withOffset.issuedAt, DateTime.utc(2026, 10, 20, 14, 30));
      expect(withOffset.issuedAt, withZ.issuedAt);
    });

    test('venceEl es una clave de día, sin hora ni corrimiento', () {
      final referral = Referral.fromJson(_json()..['venceEl'] = '2026-12-01');

      expect(referral.expiresOn, DateTime.utc(2026, 12, 1));
    });

    test('una clave de más se ignora, arriba y en la especialidad', () {
      final json = _json()
        ..['observacion'] = 'texto'
        ..['especialidadDestino'] = {
          'id': 2,
          'nombre': 'Cardiología',
          'requierePase': true,
          'codigo': 'CAR',
        };

      final referral = Referral.fromJson(json);

      expect(referral.id, 77);
      expect(referral.specialty.name, 'Cardiología');
    });

    for (final key in ['id', 'especialidadDestino', 'emitidoEn', 'venceEl']) {
      test('sin "$key" falla con TypeError', () {
        final json = _json()..remove(key);

        expect(() => Referral.fromJson(json), throwsA(isA<TypeError>()));
      });
    }

    for (final key in ['id', 'nombre', 'requierePase']) {
      test('sin "$key" en la especialidad falla con TypeError', () {
        final json = _json();
        (json['especialidadDestino'] as Map<String, dynamic>).remove(key);

        expect(() => Referral.fromJson(json), throwsA(isA<TypeError>()));
      });
    }

    test('un id como texto falla con TypeError', () {
      final json = _json()..['id'] = '77';

      expect(() => Referral.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('venceEl como dd/mm/aaaa falla con FormatException', () {
      final json = _json()..['venceEl'] = '19/11/2026';

      expect(() => Referral.fromJson(json), throwsFormatException);
    });

    test('un emitidoEn que no es una fecha falla con FormatException', () {
      final json = _json()..['emitidoEn'] = 'ayer';

      expect(() => Referral.fromJson(json), throwsFormatException);
    });
  });
}
