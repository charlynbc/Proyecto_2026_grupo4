import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/forms/early_ci_validation.dart';
import '../../../core/forms/early_field_validation.dart';
import '../../../core/forms/phone_field_rules.dart';
import '../../../core/forms/submit_state.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../auth/models/user_role.dart';
import '../../auth/widgets/credential_fields.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/new_user.dart';
import '../models/role_label.dart';
import '../providers/create_user_controller.dart';
import '../screens/user_routes.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Formulario del alta de usuario (RF-31, CU 3.5.2). El cliente valida para
/// ayudar; las reglas definitivas son del servidor.
class NewUserForm extends ConsumerStatefulWidget {
  const NewUserForm({super.key});

  @override
  ConsumerState<NewUserForm> createState() => _NewUserFormState();
}

class _NewUserFormState extends ConsumerState<NewUserForm> {
  static const int _firstYear = 1900;

  /// Los mensajes de fecha, correo y teléfono son largos: con una sola línea
  /// (lo normal) se cortan con "…".
  static const int _errorMaxLines = 3;

  final _formKey = GlobalKey<FormState>();
  final _ciController = TextEditingController();
  final _ciFocus = FocusNode();
  late final _ciValidation = EarlyCiValidation(_ciFocus);
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
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
  // El teléfono 2 es opcional: vacío nunca da error.
  late final _phone2Validation = EarlyFieldValidation(
    focusNode: _phone2Focus,
    emptyMessage: null,
    isIncomplete: isPhoneIncomplete,
    check: validateOptionalPhone,
  );
  final _addressController = TextEditingController();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  /// Ya se intentó enviar: desde ahí, la fecha vacía se reclama.
  bool _submitAttempted = false;

  /// Mientras se valida el envío, la fecha a medias avisa aunque tenga foco.
  bool _validatingSubmit = false;
  UserRole? _role;
  final Set<int> _specialtyIds = {};
  bool _specialtyMissing = false;

  @override
  void initState() {
    super.initState();
    // Sin esto no se revalidan la cédula ni los teléfonos al perder el foco.
    _ciFocus.addListener(_onFocusChanged);
    _phone1Focus.addListener(_onFocusChanged);
    _phone2Focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ciFocus.dispose();
    _phone1Focus.dispose();
    _phone2Focus.dispose();
    _ciController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  /// Las reglas propias de la fecha de nacimiento. `UiDateField` ya resolvió
  /// el formato y la fecha inexistente: acá llega vacía o como fecha válida.
  String? _validateBirthDate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return _submitAttempted ? 'Ingresá la fecha de nacimiento.' : null;
    }
    final date = parseUiDate(text)!;
    if (date.isAfter(UruguayTime.today())) {
      return 'La fecha de nacimiento no puede ser futura.';
    }
    if (date.year < _firstYear) return 'Revisá el año de nacimiento.';
    return null;
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresá el correo.';
    if (!_emailPattern.hasMatch(text)) {
      return 'Ingresá un correo válido, por ejemplo nombre@ejemplo.org.';
    }
    return null;
  }

  void _onRoleChanged(UserRole? role) {
    setState(() {
      _role = role;
      // Las especialidades son solo del Médico: al cambiar de rol se pierden.
      _specialtyIds.clear();
      _specialtyMissing = false;
    });
  }

  void _toggleSpecialty(int id, bool selected) {
    setState(() {
      selected ? _specialtyIds.add(id) : _specialtyIds.remove(id);
      _specialtyMissing = false;
    });
  }

  Future<void> _submit() async {
    // Sin foco en ningún campo, los errores del envío no se borran al
    // reconstruir el formulario.
    FocusScope.of(context).unfocus();
    setState(() {
      _autovalidate = AutovalidateMode.onUserInteraction;
      _submitAttempted = true;
    });
    // Soltar el foco no es inmediato: mientras se valida, la fecha tiene que
    // avisar de un dato a medias aunque todavía "tenga" el foco.
    _validatingSubmit = true;
    final bool formValid;
    try {
      formValid = EarlyFieldValidation.validateAllOf([
        _ciValidation,
        _phone1Validation,
        _phone2Validation,
      ], () => _formKey.currentState?.validate() ?? false);
    } finally {
      _validatingSubmit = false;
    }
    final specialtiesMissing =
        _role == UserRole.medico && _specialtyIds.isEmpty;
    setState(() => _specialtyMissing = specialtiesMissing);
    if (!formValid || specialtiesMissing) return;

    final phone2 = _phone2Controller.text.trim();
    final address = _addressController.text.trim();
    await ref
        .read(createUserControllerProvider.notifier)
        .submit(
          NewUser(
            ci: _ciController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            birthDate: parseUiDate(_birthDateController.text.trim())!,
            email: _emailController.text.trim(),
            phone1: _phone1Controller.text.trim(),
            phone2: phone2.isEmpty ? null : phone2,
            address: address.isEmpty ? null : address,
            role: _role!,
            specialtyIds: _role == UserRole.medico
                ? (_specialtyIds.toList()..sort())
                : const [],
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(createUserControllerProvider, (_, state) {
      if (state.status == SubmitStatus.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Usuario registrado. La persona activa su cuenta desde la '
              'pantalla de ingreso con «Es mi primera vez».',
            ),
          ),
        );
        context.go(kUsersPath);
      }
    });
    final state = ref.watch(createUserControllerProvider);
    final enabled = !state.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CiFormField(
            controller: _ciController,
            focusNode: _ciFocus,
            validator: _ciValidation.validate,
            enabled: enabled,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) => _required(v, 'Ingresá el nombre.'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Apellido'),
            validator: (v) => _required(v, 'Ingresá el apellido.'),
          ),
          const SizedBox(height: 16),
          UiDateField(
            controller: _birthDateController,
            enabled: enabled,
            label: 'Fecha de nacimiento (dd/mm/aaaa)',
            pickerHelpText: 'Fecha de nacimiento',
            pickerTooltip: 'Elegir fecha de nacimiento',
            // Solo pasado: desde 1900 hasta hoy, en la hora de Uruguay.
            firstDate: DateTime.utc(_firstYear),
            lastDate: UruguayTime.today(),
            textInputAction: TextInputAction.next,
            errorMaxLines: _errorMaxLines,
            showErrorsNow: () => _validatingSubmit,
            validator: _validateBirthDate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              errorMaxLines: _errorMaxLines,
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone1Controller,
            focusNode: _phone1Focus,
            enabled: enabled,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            keyboardType: TextInputType.phone,
            inputFormatters: kPhoneInputFormatters,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Teléfono 1',
              errorMaxLines: _errorMaxLines,
            ),
            validator: _phone1Validation.validate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone2Controller,
            focusNode: _phone2Focus,
            enabled: enabled,
            autovalidateMode: AutovalidateMode.onUserInteraction,
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
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Dirección (opcional)',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            isExpanded: true,
            autovalidateMode: _autovalidate,
            decoration: const InputDecoration(labelText: 'Rol'),
            items: [
              for (final role in UserRole.values)
                DropdownMenuItem(value: role, child: Text(roleLabel(role))),
            ],
            onChanged: enabled ? _onRoleChanged : null,
            validator: (v) => v == null ? 'Elegí el rol.' : null,
          ),
          if (_role == UserRole.medico) ...[
            const SizedBox(height: 16),
            _SpecialtiesPicker(
              selected: _specialtyIds,
              enabled: enabled,
              showMissingError: _specialtyMissing,
              onChanged: _toggleSpecialty,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'No se envía ningún correo al registrar: la persona activa su '
            'cuenta con «Es mi primera vez».',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: enabled ? _submit : null,
            child: state.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Registrar usuario'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: enabled ? () => context.go(kUsersPath) : null,
            child: const Text('Cancelar'),
          ),
          if (state.status == SubmitStatus.error) ...[
            const SizedBox(height: 12),
            Text(
              state.errorMessage ?? '',
              style: TextStyle(color: colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// Las especialidades del catálogo, para elegir una o más (solo Médico).
class _SpecialtiesPicker extends ConsumerWidget {
  const _SpecialtiesPicker({
    required this.selected,
    required this.enabled,
    required this.showMissingError,
    required this.onChanged,
  });

  final Set<int> selected;
  final bool enabled;
  final bool showMissingError;
  final void Function(int id, bool selected) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specialties = ref.watch(specialtiesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Especialidades (elegí una o más)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ...specialties.when(
          loading: () => const [
            Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (error, _) => [
            Text(
              'No pudimos cargar las especialidades. Intentá de nuevo.',
              style: TextStyle(color: colorScheme.error),
            ),
            OutlinedButton(
              onPressed: () => ref.invalidate(specialtiesProvider),
              child: const Text('Reintentar'),
            ),
          ],
          data: (items) => [
            for (final specialty in items)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(specialty.name),
                value: selected.contains(specialty.id),
                onChanged: enabled
                    ? (value) => onChanged(specialty.id, value ?? false)
                    : null,
              ),
          ],
        ),
        if (showMissingError)
          Text(
            'Elegí al menos una especialidad para el médico.',
            style: TextStyle(color: colorScheme.error),
          ),
      ],
    );
  }
}
