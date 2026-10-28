import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/forms/submit_state.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/medico/models/doctor_appointment_result.dart';
import 'package:agenda_medica/features/medico/providers/doctor_result_controller.dart';
import 'package:agenda_medica/features/medico/providers/doctor_result_repository_provider.dart';
import 'package:agenda_medica/features/medico/providers/referral_specialties_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_result_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_result_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Con la semilla de FakeAdminDatabase: 2 Cardiología y 3 Dermatología (esta
// última es la que el fake responde como PASE_DUPLICADO).
const _cardiology = 2;

/// Anota los pedidos, puede frenarlos con [gate] y fallar con [failure]; si no,
/// responde como el fake.
class _RecordingRepository implements DoctorResultRepository {
  _RecordingRepository({this.gate, this.failure})
    : _fake = FakeDoctorResultRepository(
        FakeAdminDatabase(),
        latency: Duration.zero,
      );

  final Completer<void>? gate;
  final Object? failure;
  final FakeDoctorResultRepository _fake;
  int calls = 0;
  AppointmentResultRequest? lastRequest;

  @override
  Future<AppointmentResult> register(
    int appointmentId,
    AppointmentResultRequest request,
  ) async {
    calls++;
    lastRequest = request;
    await gate?.future;
    if (failure != null) throw failure!;
    return _fake.register(appointmentId, request);
  }
}

(ProviderContainer, DoctorResultController, _RecordingRepository) _setup({
  Completer<void>? gate,
  Object? failure,
}) {
  final repository = _RecordingRepository(gate: gate, failure: failure);
  final container = ProviderContainer(
    overrides: [
      doctorResultRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  addTearDown(container.dispose);
  container.listen(doctorResultControllerProvider, (_, _) {});
  return (
    container,
    container.read(doctorResultControllerProvider.notifier),
    repository,
  );
}

DoctorResultFormState _state(ProviderContainer container) =>
    container.read(doctorResultControllerProvider);

void main() {
  group('vigencia de un pase', () {
    for (final (text, days) in [('1', 1), ('365', 365), ('', 90), ('30', 30)]) {
      test('"$text" se acepta como $days días', () {
        final (container, controller, _) = _setup();

        final added = controller.addReferral(
          specialtyId: _cardiology,
          validityText: text,
        );

        expect(added, isTrue);
        expect(_state(container).referralError, isNull);
        expect(_state(container).referrals, hasLength(1));
        expect(_state(container).referrals.single.specialtyId, _cardiology);
        expect(_state(container).referrals.single.validityDays, days);
      });
    }

    for (final text in ['0', '366', '-5', 'abc', '1.5']) {
      test('"$text" se rechaza con su aviso', () {
        final (container, controller, _) = _setup();

        final added = controller.addReferral(
          specialtyId: _cardiology,
          validityText: text,
        );

        expect(added, isFalse);
        expect(_state(container).referrals, isEmpty);
        expect(
          _state(container).referralError,
          'La vigencia tiene que ser un número de días entre 1 y 365.',
        );
      });
    }
  });

  group('especialidades repetidas', () {
    test('no se puede agregar dos veces la misma', () {
      final (container, controller, _) = _setup();
      controller.addReferral(specialtyId: _cardiology);

      final again = controller.addReferral(
        specialtyId: _cardiology,
        validityText: '10',
      );

      expect(again, isFalse);
      expect(_state(container).referrals, hasLength(1));
      expect(_state(container).referrals.single.validityDays, 90);
      expect(
        _state(container).referralError,
        'Ya agregaste un pase para esa especialidad.',
      );
    });

    test('quitar un pase permite volver a agregar esa especialidad', () {
      final (container, controller, _) = _setup();
      controller.addReferral(specialtyId: _cardiology);
      controller.removeReferral(_cardiology);

      expect(_state(container).referrals, isEmpty);
      expect(controller.addReferral(specialtyId: _cardiology), isTrue);
    });
  });

  group('afección obligatoria', () {
    for (final condition in ['', '   ']) {
      test(
        'ATENDIDA con afección "$condition" no se envía y marca el campo',
        () async {
          final (container, controller, repository) = _setup();
          controller.setCondition(condition);

          final result = await controller.submit(15);

          expect(result, isNull);
          expect(repository.calls, 0);
          expect(_state(container).status, SubmitStatus.idle);
          expect(
            _state(container).conditionError,
            'Escribí la afección que se diagnosticó.',
          );
        },
      );
    }

    test('validate marca la afección vacía de Atendida y no envía', () {
      final (container, controller, repository) = _setup();
      controller.setCondition('   ');

      expect(controller.validate(), isFalse);

      expect(
        _state(container).conditionError,
        'Escribí la afección que se diagnosticó.',
      );
      expect(repository.calls, 0);
    });

    test('validate acepta Atendida con afección y No se presentó vacío', () {
      final (container, controller, _) = _setup();
      controller.setCondition('gripe');
      expect(controller.validate(), isTrue);
      expect(_state(container).conditionError, isNull);

      controller.setCondition('');
      controller.setOutcome(ConsultationOutcome.noShow);
      expect(controller.validate(), isTrue);
      expect(_state(container).conditionError, isNull);
    });

    test('pasar a No se presentó limpia la marca de la afección', () async {
      final (container, controller, _) = _setup();
      await controller.submit(15);
      expect(_state(container).conditionError, isNotNull);

      controller.setOutcome(ConsultationOutcome.noShow);

      expect(_state(container).conditionError, isNull);
    });

    test('volver a Atendida no trae de vuelta la marca', () async {
      final (container, controller, _) = _setup();
      await controller.submit(15);
      controller.setOutcome(ConsultationOutcome.noShow);

      controller.setOutcome(ConsultationOutcome.attended);

      expect(_state(container).conditionError, isNull);
    });

    test('escribir la afección limpia la marca', () async {
      final (container, controller, _) = _setup();
      await controller.submit(15);
      expect(_state(container).conditionError, isNotNull);

      controller.setCondition('gripe');

      expect(_state(container).conditionError, isNull);
    });
  });

  group('envío', () {
    test('ATENDIDA guarda el resultado con sus pases', () async {
      final (container, controller, repository) = _setup();
      controller.setCondition('  gripe ');
      controller.setTreatment('reposo');
      controller.addReferral(specialtyId: _cardiology, validityText: '30');

      final result = await controller.submit(15);

      expect(repository.lastRequest!.toJson(), {
        'resultado': 'ATENDIDA',
        'afeccion': 'gripe',
        'tratamiento': 'reposo',
        'pases': [
          {'especialidadDestinoId': 2, 'vigenciaDias': 30},
        ],
      });
      expect(_state(container).status, SubmitStatus.done);
      expect(_state(container).result, same(result));
      expect(result!.attentionId, 1015);
      expect(result.referrals.single.specialty.name, 'Cardiología');
    });

    test('ATENDIDA con observaciones las envía recortadas', () async {
      final (_, controller, repository) = _setup();
      controller.setCondition('gripe');
      controller.setNotes('  control en 7 dias ');

      await controller.submit(15);

      expect(repository.lastRequest!.toJson(), {
        'resultado': 'ATENDIDA',
        'afeccion': 'gripe',
        'observaciones': 'control en 7 dias',
      });
    });

    test(
      'el resultado es definitivo: tras un éxito no hay un segundo envío',
      () async {
        final (container, controller, repository) = _setup();
        controller.setCondition('gripe');
        final first = await controller.submit(15);
        expect(first, isNotNull);
        expect(repository.calls, 1);

        final second = await controller.submit(15);

        expect(second, isNull);
        expect(repository.calls, 1);
        expect(_state(container).status, SubmitStatus.done);
        expect(_state(container).result, same(first));
      },
    );

    test('NO_SE_PRESENTO envía solo {resultado} aunque haya texto', () async {
      final (container, controller, repository) = _setup();
      controller.setCondition('gripe');
      controller.setTreatment('reposo');
      controller.setNotes('nota');
      controller.addReferral(specialtyId: _cardiology);
      controller.setOutcome(ConsultationOutcome.noShow);

      await controller.submit(15);

      expect(repository.lastRequest!.toJson(), {'resultado': 'NO_SE_PRESENTO'});
      expect(_state(container).status, SubmitStatus.done);
      expect(_state(container).result!.attentionId, isNull);
      expect(_state(container).result!.referrals, isEmpty);
    });

    test('NO_SE_PRESENTO no exige afección', () async {
      final (container, controller, repository) = _setup();
      controller.setOutcome(ConsultationOutcome.noShow);

      await controller.submit(15);

      expect(repository.calls, 1);
      expect(_state(container).conditionError, isNull);
    });
  });

  group('errores del servidor', () {
    test('PASE_DUPLICADO desde el fake queda con su mensaje', () async {
      final (container, controller, _) = _setup();
      controller.setCondition('gripe');
      controller.addReferral(specialtyId: kFakeDuplicateReferralSpecialtyId);

      final result = await controller.submit(15);

      expect(result, isNull);
      expect(_state(container).status, SubmitStatus.error);
      expect(
        _state(container).errorMessage,
        const DuplicateReferralException().message,
      );
      expect(_state(container).result, isNull);
    });

    test('CONSULTA_NO_ES_DE_HOY desde el fake queda con su mensaje', () async {
      final (container, controller, _) = _setup();
      controller.setCondition('gripe');

      await controller.submit(kFakeNotTodayAppointmentId);

      expect(_state(container).status, SubmitStatus.error);
      expect(
        _state(container).errorMessage,
        const AppointmentNotTodayException().message,
      );
    });

    final failures = <(String, ApiException)>[
      ('VALIDACION', const ResultValidationException()),
      ('CONFLICTO_DE_INTERES', const ConflictOfInterestException()),
      ('NO_ENCONTRADO', const ResultAppointmentNotFoundException()),
      ('CONSULTA_NO_AGENDADA', const AppointmentNotScheduledException()),
      ('CONSULTA_NO_ES_DE_HOY', const AppointmentNotTodayException()),
      ('SIN_AVISO_LLEGADA', const NoArrivalNoticeException()),
      ('PASE_DUPLICADO', const DuplicateReferralException()),
    ];
    for (final (code, exception) in failures) {
      test('$code se muestra con su mensaje y sin el código', () async {
        final (container, controller, _) = _setup(failure: exception);
        controller.setCondition('gripe');

        await controller.submit(15);

        final message = _state(container).errorMessage!;
        expect(_state(container).status, SubmitStatus.error);
        expect(message, exception.message);
        expect(message, isNot(contains(code)));
      });
    }

    test(
      'un error que no es de la API queda como el mensaje genérico',
      () async {
        final (container, controller, _) = _setup(failure: StateError('x'));
        controller.setCondition('gripe');

        await controller.submit(15);

        expect(_state(container).errorMessage, kApiGenericMessage);
      },
    );

    test('un intento nuevo limpia el error anterior', () async {
      final (container, controller, _) = _setup();
      controller.setCondition('gripe');
      await controller.submit(kFakeNotTodayAppointmentId);
      expect(_state(container).errorMessage, isNotNull);

      await controller.submit(15);

      expect(_state(container).errorMessage, isNull);
      expect(_state(container).status, SubmitStatus.done);
    });
  });

  group('doble envío', () {
    test(
      'un segundo submit en curso no llama otra vez al repositorio',
      () async {
        final gate = Completer<void>();
        final (container, controller, repository) = _setup(gate: gate);
        controller.setCondition('gripe');

        final first = controller.submit(15);
        await Future<void>.delayed(Duration.zero);
        expect(_state(container).status, SubmitStatus.loading);
        final second = await controller.submit(15);

        expect(second, isNull);
        expect(repository.calls, 1);

        gate.complete();
        final result = await first;

        expect(result, isNotNull);
        expect(repository.calls, 1);
        expect(_state(container).status, SubmitStatus.done);
      },
    );
  });

  group('especialidades que se ofrecen', () {
    test('solo las que requieren pase', () async {
      final container = ProviderContainer(
        overrides: [
          specialtyRepositoryProvider.overrideWith(
            (ref) async => FakeSpecialtyRepository(
              FakeAdminDatabase(),
              latency: Duration.zero,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final offered = await container.read(referralSpecialtiesProvider.future);

      expect(
        [for (final s in offered) s.name],
        ['Cardiología', 'Dermatología'],
      );
      expect(offered.every((s) => s.requiresReferral), isTrue);
    });
  });
}
