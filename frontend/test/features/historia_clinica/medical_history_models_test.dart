import 'package:flutter_test/flutter_test.dart';

import 'package:agenda_medica/core/utils/ui_date.dart';
import 'package:agenda_medica/features/historia_clinica/models/history_referral.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';

void main() {
  group('MedicalHistoryEntry.fromJson', () {
    test(
      'interpreta la atención de Trello con campos opcionales nulos '
      'y sin pases',
      () {
        final entry = MedicalHistoryEntry.fromJson({
          'idAtencion': 10,
          'fechaAtencion': '2026-09-24',
          'medicoId': 4,
          'medicoNombre': 'Diego',
          'medicoApellido': 'Viera',
          'especialidad': {
            'id': 3,
            'nombre': 'Cardiología',
            'requierePase': true,
          },
          'afeccion': 'gripe',
          'tratamiento': null,
          'observaciones': null,
          'pases': <dynamic>[],
        });

        expect(entry.id, 10);
        expect(formatUiDate(entry.attendedOn), '24/09/2026');

        expect(entry.doctorId, 4);
        expect(entry.doctorFirstName, 'Diego');
        expect(entry.doctorLastName, 'Viera');
        expect(entry.doctorFullName, 'Diego Viera');

        expect(entry.specialty.id, 3);
        expect(entry.specialty.name, 'Cardiología');
        expect(entry.specialty.requiresReferral, isTrue);

        expect(entry.condition, 'gripe');
        expect(entry.treatment, isNull);
        expect(entry.observations, isNull);
        expect(entry.referrals, hasLength(0));
      },
    );
  });

  group('HistoryReferral.fromJson', () {
    test(
      'interpreta el pase de Trello con especialidad destino '
      'y fecha de vencimiento',
      () {
        final referral = HistoryReferral.fromJson({
          'id': 7,
          'especialidad': {
            'id': 5,
            'nombre': 'Traumatología',
            'requierePase': true,
          },
          'emitidoEn': '2026-09-24T10:00:00-03:00',
          'venceEl': '2026-12-23',
        });

        expect(referral.id, 7);
        expect(referral.specialty.id, 5);
        expect(referral.specialty.name, 'Traumatología');
        expect(referral.specialty.requiresReferral, isTrue);

        expect(referral.issuedAt, '2026-09-24T10:00:00-03:00');
        expect(formatUiDate(referral.expiresOn), '23/12/2026');
      },
    );
  });
}
