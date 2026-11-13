import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/early_ci_validation.dart';
import '../../../core/forms/early_field_validation.dart';
import '../../../core/forms/email_field_rules.dart';
import '../../../core/forms/phone_field_rules.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart' show formatUiDate;
import '../../../core/utils/uruguay_time.dart';
import '../../auth/models/user_role.dart';
import '../../auth/widgets/credential_fields.dart';
import '../models/account_detail.dart';
import '../models/role_label.dart';
import '../providers/correct_user_controller.dart';
import '../repositories/user_correction_repository.dart';
import '../screens/user_routes.dart';
import 'new_user_form.dart'
    show SpecialtiesPicker, kFirstBirthYear, parseUiDate, validateBirthDateText;

/// Formulario de corrección de los datos de una cuenta (RF-38). Parte de los
/// datos actuales y manda solo lo que cambió. El cliente valida para ayudar;
/// las reglas definitivas son del servidor.
class EditUserForm extends ConsumerStatefulWidget {
  const EditUserForm({super.key, required this.detail});

  final AccountDetail detail;

  @override
  ConsumerState<EditUserForm> createState() => _EditUserFormState();
}

class _EditUserFormState extends ConsumerState<EditUserForm> {
  /// Largo de `dd/mm/aaaa`.
  static const int _dateLength = 10;
  static const int _maxName = 100;
  static const int _maxEmail = 254;
  static const int _maxPhone = 30;

  /// Los mensajes largos se cortan con "…" si tienen una sola línea.
  static const int _errorMaxLines = 3;

  final _formKey = GlobalKey<FormState>();
  final _ciController = TextEditingController();
  final _ciFocus = FocusNode();
  late final _ciValidation = EarlyCiValidation(_ciFocus);
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _birthDateFocus = FocusNode();
  late final _birthDateValidation = EarlyFieldValidation(
    focusNode: _birthDateFocus,
    emptyMessage: 'Ingresá la fecha de nacimiento.',
    completeLength: _dateLength,
    check: validateBirthDateText,
  );
  final _emailController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone1Focus = FocusNode();
  late final _phone1Validation = EarlyFieldValidation(
    focusNode: _phone1Focus,
    emptyMessage: 'Ingresá un teléfono.',
    isIncomplete: isPhoneIncomplete,
    check: validateOptionalPhone,
  );
  final _phone2Controller = TextEditingController();
  final _phone2Focus = FocusNode();
  late final _phone2Validation = EarlyFieldValidation(
    focusNode: _phone2Focus,
    emptyMessage: null,
    isIncomplete: isPhoneIncomplete,
    check: validateOptionalPhone,
  );
  final _addressController = TextEditingController();

  late final Set<int> _specialtyIds = {...widget.detail.specialtyIds};
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _specialtyMissing = false;

  /// La CI que se mandó la última vez: un error del servidor sobre ella se
  /// saca cuando el administrador la cambia.
  String? _ciSent;

  AccountDetail get _detail => widget.detail;
  bool get _isDoctor => _detail.role == UserRole.medico;

  List<TextEditingController> get _controllers => [
    _ciController,
    _firstNameController,
    _lastNameController,
    _birthDateController,
    _emailController,
    _phone1Controller,
    _phone2Controller,
    _addressController,
  ];

  @override
  void initState() {
    super.initState();
    _ciController.text = _detail.ci;
    _firstNameController.text = _detail.firstName;
    _lastNameController.text = _detail.lastName;
    _birthDateController.text = formatUiDate(_detail.birthDate);
    _emailController.text = _detail.email;
    _phone1Controller.text = _detail.phone1;
    _phone2Controller.text = _detail.phone2 ?? '';
    _addressController.text = _detail.address ?? '';
    for (final controller in _controllers) {
      controller.addListener(_onChanged);
    }
    // Sin esto no se revalidan la cédula, la fecha ni los teléfonos al perder
    // el foco.
    for (final focus in [
      _ciFocus,
      _birthDateFocus,
      _phone1Focus,
      _phone2Focus,
    ]) {
      focus.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    for (final focus in [
      _ciFocus,
      _birthDateFocus,
      _phone1Focus,
      _phone2Focus,
    ]) {
      focus.dispose();
    }
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    if (!mounted) return;
    final state = ref.read(correctUserControllerProvider);
    final ciFailed =
        state.failure == UserCorrectionFailure.invalidCi ||
        state.failure == UserCorrectionFailure.ciInUse;
    if (state.status == SubmitStatus.error &&
        ciFailed &&
        _ciController.text.trim() != _ciSent) {
      ref.read(correctUserControllerProvider.notifier).clearError();
    }
    setState(() {});
  }

  String? _required(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  bool get _ciChanged => _ciController.text.trim() != _detail.ci;

  bool get _birthDateChanged =>
      _birthDateController.text.trim() != formatUiDate(_detail.birthDate);

  String? _changed(String text, String original) {
    final value = text.trim();
    return value == original.trim() ? null : value;
  }

  /// El cambio de un texto que se puede borrar, o `null` si no cambió.
  TextChange? _textChange(String text, String? original) {
    final value = text.trim();
    if (value == (original?.trim() ?? '')) return null;
    return value.isEmpty ? const TextChange.clear() : TextChange.set(value);
  }

  /// Solo lo que difiere de los datos actuales, con los textos recortados y
  /// el correo en minúsculas.
  AccountCorrection _correction() {
    final email = _emailController.text.trim().toLowerCase();
    final specialties = _specialtyIds.toList()..sort();
    final originalSpecialties = [..._detail.specialtyIds]..sort();
    return AccountCorrection(
      ci: _changed(_ciController.text, _detail.ci),
      firstName: _changed(_firstNameController.text, _detail.firstName),
      lastName: _changed(_lastNameController.text, _detail.lastName),
      birthDate: _birthDateChanged
          ? parseUiDate(_birthDateController.text)
          : null,
      email: email == _detail.email.toLowerCase() ? null : email,
      phone1: _changed(_phone1Controller.text, _detail.phone1),
      phone2: _textChange(_phone2Controller.text, _detail.phone2),
      address: _textChange(_addressController.text, _detail.address),
      specialtyIds: _isDoctor && !_sameList(specialties, originalSpecialties)
          ? specialties
          : null,
    );
  }

  bool _sameList(List<int> a, List<int> b) =>
      a.length == b.length &&
      [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((same) => same);

  bool get _hasChanges => !_correction().isEmpty || _birthDateChanged;

  Future<void> _pickBirthDate() async {
    final today = UruguayTime.today();
    final last = DateTime(today.year, today.month, today.day);
    final initial = parseUiDate(_birthDateController.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial != null && !initial.isAfter(last) ? initial : last,
      firstDate: DateTime(kFirstBirthYear),
      lastDate: last,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null || !mounted) return;
    _birthDateController.text = formatUiDate(picked);
  }

  void _toggleSpecialty(int id, bool selected) {
    setState(() {
      selected ? _specialtyIds.add(id) : _specialtyIds.remove(id);
      _specialtyMissing = false;
    });
    final state = ref.read(correctUserControllerProvider);
    if (state.failure == UserCorrectionFailure.specialtyInUse) {
      ref.read(correctUserControllerProvider.notifier).clearError();
    }
  }

  Future<void> _submit() async {
    if (ref.read(correctUserControllerProvider).isLoading) return;
    // Sin foco en ningún campo, los errores del envío no se borran al
    // reconstruir el formulario.
    FocusScope.of(context).unfocus();
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    final formValid = EarlyFieldValidation.validateAllOf([
      _ciValidation,
      _birthDateValidation,
      _phone1Validation,
      _phone2Validation,
    ], () => _formKey.currentState?.validate() ?? false);
    final specialtiesMissing = _isDoctor && _specialtyIds.isEmpty;
    setState(() => _specialtyMissing = specialtiesMissing);
    if (!formValid || specialtiesMissing) return;

    final correction = _correction();
    if (correction.isEmpty) return;
    _ciSent = _ciController.text.trim();
    await ref
        .read(correctUserControllerProvider.notifier)
        .correct(_detail.id, correction);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(correctUserControllerProvider, (_, state) {
      if (state.status == SubmitStatus.done) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Datos corregidos.')));
        context.go(kUsersPath);
      }
    });
    final state = ref.watch(correctUserControllerProvider);
    final enabled = !state.isLoading;
    final errorColor = Theme.of(context).colorScheme.error;
    final failed = state.status == SubmitStatus.error;
    final ciError =
        failed &&
            (state.failure == UserCorrectionFailure.invalidCi ||
                state.failure == UserCorrectionFailure.ciInUse)
        ? state.errorMessage
        : null;
    final specialtyError =
        failed && state.failure == UserCorrectionFailure.specialtyInUse
        ? state.errorMessage
        : null;
    final topError = failed && ciError == null && specialtyError == null
        ? (state.errorMessage ?? kApiGenericMessage)
        : null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topError != null) ...[
            Text(
              topError,
              key: const Key('edit-user-error'),
              style: TextStyle(color: errorColor),
            ),
            const SizedBox(height: 12),
          ],
          InputDecorator(
            key: const Key('edit-user-role'),
            decoration: const InputDecoration(labelText: 'Rol'),
            child: Text(roleLabel(_detail.role)),
          ),
          const SizedBox(height: 16),
          CiFormField(
            controller: _ciController,
            focusNode: _ciFocus,
            validator: _ciValidation.validate,
            enabled: enabled,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          if (ciError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                ciError,
                key: const Key('edit-user-ci-error'),
                style: TextStyle(color: errorColor),
              ),
            ),
          if (_ciChanged)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'La CI es un dato de la persona: el cambio vale para todas '
                'sus cuentas.',
                key: const Key('edit-user-ci-notice'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            maxLength: _maxName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) => _required(v, 'Ingresá el nombre.'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _lastNameController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            maxLength: _maxName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Apellido'),
            validator: (v) => _required(v, 'Ingresá el apellido.'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _birthDateController,
            focusNode: _birthDateFocus,
            enabled: enabled,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
              LengthLimitingTextInputFormatter(_dateLength),
            ],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Fecha de nacimiento (dd/mm/aaaa)',
              errorMaxLines: _errorMaxLines,
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                tooltip: 'Elegir fecha de nacimiento',
                onPressed: enabled ? _pickBirthDate : null,
              ),
            ),
            validator: _birthDateValidation.validate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            maxLength: _maxEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              errorMaxLines: _errorMaxLines,
            ),
            validator: validateEmail,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phone1Controller,
            focusNode: _phone1Focus,
            enabled: enabled,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            maxLength: _maxPhone,
            keyboardType: TextInputType.phone,
            inputFormatters: kPhoneInputFormatters,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Teléfono 1',
              errorMaxLines: _errorMaxLines,
            ),
            validator: _phone1Validation.validate,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phone2Controller,
            focusNode: _phone2Focus,
            enabled: enabled,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            maxLength: _maxPhone,
            keyboardType: TextInputType.phone,
            inputFormatters: kPhoneInputFormatters,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Teléfono 2 (opcional)',
              errorMaxLines: _errorMaxLines,
            ),
            validator: _phone2Validation.validate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              // Una cuenta que ya completó el primer ingreso conserva su
              // dirección (RF-02).
              labelText: _detail.activated
                  ? 'Dirección'
                  : 'Dirección (opcional)',
            ),
            validator: _detail.activated
                ? (v) => _required(v, 'Ingresá la dirección.')
                : null,
          ),
          if (_isDoctor) ...[
            const SizedBox(height: 16),
            SpecialtiesPicker(
              selected: _specialtyIds,
              enabled: enabled,
              showMissingError: _specialtyMissing,
              onChanged: _toggleSpecialty,
            ),
            if (specialtyError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  specialtyError,
                  key: const Key('edit-user-specialty-error'),
                  style: TextStyle(color: errorColor),
                ),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('edit-user-save'),
            onPressed: enabled && _hasChanges ? _submit : null,
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: enabled ? () => context.go(kUsersPath) : null,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
