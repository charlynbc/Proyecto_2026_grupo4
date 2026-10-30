import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../models/doctor_appointment_result.dart';
import 'doctor_result_repository_provider.dart';

const String kReferralValidityMessage =
    'La vigencia tiene que ser un número de días entre 1 y 365.';
const String kDuplicateReferralFieldMessage =
    'Ya agregaste un pase para esa especialidad.';
const String kMissingConditionMessage =
    'Escribí la afección que se diagnosticó.';

const Object _keep = Object();

/// El formulario del resultado de una consulta (RF-23 y RF-24) y el estado de
/// su envío.
class DoctorResultFormState {
  const DoctorResultFormState({
    this.outcome = ConsultationOutcome.attended,
    this.condition = '',
    this.treatment = '',
    this.notes = '',
    this.referrals = const [],
    this.conditionError,
    this.referralError,
    this.status = SubmitStatus.idle,
    this.errorMessage,
    this.result,
  });

  final ConsultationOutcome outcome;
  final String condition;
  final String treatment;
  final String notes;
  final List<ReferralRequest> referrals;

  /// Aviso del campo de la afección, o `null`.
  final String? conditionError;

  /// Aviso de la sección de pases (vigencia o especialidad repetida), o `null`.
  final String? referralError;
  final SubmitStatus status;

  /// Solo con [SubmitStatus.error]: texto para mostrar al usuario.
  final String? errorMessage;

  /// Solo con [SubmitStatus.done]: lo que registró el servidor.
  final AppointmentResult? result;

  bool get isLoading => status == SubmitStatus.loading;

  /// Los campos anulables se limpian pasando `null` y se conservan si no se
  /// nombran.
  DoctorResultFormState copyWith({
    ConsultationOutcome? outcome,
    String? condition,
    String? treatment,
    String? notes,
    List<ReferralRequest>? referrals,
    Object? conditionError = _keep,
    Object? referralError = _keep,
    SubmitStatus? status,
    Object? errorMessage = _keep,
    Object? result = _keep,
  }) => DoctorResultFormState(
    outcome: outcome ?? this.outcome,
    condition: condition ?? this.condition,
    treatment: treatment ?? this.treatment,
    notes: notes ?? this.notes,
    referrals: referrals ?? this.referrals,
    conditionError: identical(conditionError, _keep)
        ? this.conditionError
        : conditionError as String?,
    referralError: identical(referralError, _keep)
        ? this.referralError
        : referralError as String?,
    status: status ?? this.status,
    errorMessage: identical(errorMessage, _keep)
        ? this.errorMessage
        : errorMessage as String?,
    result: identical(result, _keep)
        ? this.result
        : result as AppointmentResult?,
  );
}

/// Carga y envío del resultado de una consulta. El resultado es definitivo:
/// no hay segundo envío mientras uno está en curso.
class DoctorResultController extends Notifier<DoctorResultFormState> {
  @override
  DoctorResultFormState build() => const DoctorResultFormState();

  void setOutcome(ConsultationOutcome outcome) {
    // La marca de la afección solo vale para Atendida: no queda guardada.
    state = state.copyWith(outcome: outcome, conditionError: null);
  }

  void setCondition(String text) {
    state = state.copyWith(condition: text, conditionError: null);
  }

  void setTreatment(String text) {
    state = state.copyWith(treatment: text);
  }

  void setNotes(String text) {
    state = state.copyWith(notes: text);
  }

  /// Agrega un pase a [specialtyId]. [validityText] vacío usa la vigencia por
  /// defecto. Devuelve si se agregó; si no, [DoctorResultFormState.referralError]
  /// dice por qué.
  bool addReferral({required int specialtyId, String validityText = ''}) {
    final text = validityText.trim();
    final days = text.isEmpty
        ? kDefaultReferralValidityDays
        : int.tryParse(text);
    if (days == null ||
        days < kMinReferralValidityDays ||
        days > kMaxReferralValidityDays) {
      state = state.copyWith(referralError: kReferralValidityMessage);
      return false;
    }
    if (state.referrals.any((r) => r.specialtyId == specialtyId)) {
      state = state.copyWith(referralError: kDuplicateReferralFieldMessage);
      return false;
    }
    state = state.copyWith(
      referrals: [
        ...state.referrals,
        ReferralRequest(specialtyId: specialtyId, validityDays: days),
      ],
      referralError: null,
    );
    return true;
  }

  void removeReferral(int specialtyId) {
    state = state.copyWith(
      referrals: [
        for (final r in state.referrals)
          if (r.specialtyId != specialtyId) r,
      ],
      referralError: null,
    );
  }

  /// Si el formulario se puede enviar. Con Atendida exige la afección y, si
  /// falta, marca el campo. Con No se presentó no pide nada.
  bool validate() {
    if (state.outcome == ConsultationOutcome.attended &&
        state.condition.trim().isEmpty) {
      state = state.copyWith(conditionError: kMissingConditionMessage);
      return false;
    }
    return true;
  }

  /// Envía el resultado de la consulta [appointmentId]. Devuelve lo registrado,
  /// o `null` si no se envió o falló; en ese caso el estado dice por qué.
  Future<AppointmentResult?> submit(int appointmentId) async {
    // El resultado es definitivo: ni en curso ni ya registrado hay otro envío.
    if (state.isLoading || state.status == SubmitStatus.done) return null;
    if (!validate()) {
      state = state.copyWith(status: SubmitStatus.idle, errorMessage: null);
      return null;
    }
    // Si se sale de la pantalla mientras se envía, el envío igual termina.
    final link = ref.keepAlive();
    state = state.copyWith(status: SubmitStatus.loading, errorMessage: null);
    try {
      final repository = await ref.read(doctorResultRepositoryProvider.future);
      final request = AppointmentResultRequest(
        outcome: state.outcome,
        condition: state.condition.trim(),
        treatment: state.treatment.trim(),
        notes: state.notes.trim(),
        referrals: state.referrals,
      );
      final result = await repository.register(appointmentId, request);
      state = state.copyWith(status: SubmitStatus.done, result: result);
      return result;
    } catch (e) {
      state = state.copyWith(
        status: SubmitStatus.error,
        errorMessage: apiMessageOf(e),
      );
      return null;
    } finally {
      link.close();
    }
  }
}

final doctorResultControllerProvider =
    NotifierProvider.autoDispose<DoctorResultController, DoctorResultFormState>(
      DoctorResultController.new,
    );
