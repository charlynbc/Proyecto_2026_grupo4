import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../../core/validators/uruguayan_ci_validator.dart';
import '../../auth/models/user_role.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/new_user.dart';
import '../models/role_label.dart';
import '../providers/create_user_controller.dart';
import '../screens/user_routes.dart';

final DateFormat _uiDate = DateFormat('dd/MM/yyyy');
final RegExp _datePattern = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _ciCharacters = RegExp(r'^[\d.\-\s]+$');

/// La CI sin puntos, guiones ni espacios, o `null` si trae otros caracteres.
String? normalizeCi(String raw) {
  if (!_ciCharacters.hasMatch(raw)) return null;
  return raw.replaceAll(RegExp(r'[.\-\s]'), '');
}

/// Una fecha `dd/mm/aaaa` real (no `31/02/2000`), o `null`.
DateTime? parseUiDate(String text) {
  final match = _datePattern.firstMatch(text.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Formulario del alta de usuario (RF-31, CU 3.5.2). El cliente valida para
/// ayudar; las reglas definitivas son del servidor.
class NewUserForm extends ConsumerStatefulWidget {
  const NewUserForm({super.key});

  @override
  ConsumerState<NewUserForm> createState() => _NewUserFormState();
}

class _NewUserFormState extends ConsumerState<NewUserForm> {
  static const int _firstYear = 1900;

  final _formKey = GlobalKey<FormState>();
  final _ciController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _addressController = TextEditingController();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  UserRole? _role;
  final Set<int> _specialtyIds = {};
  bool _specialtyMissing = false;

  @override
  void dispose() {
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

  String? _validateCi(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Ingresá la cédula.';
    final ci = normalizeCi(raw);
    if (ci == null || !isValidUruguayanCi(ci)) {
      return 'La cédula no es válida. Revisá los números, incluido el último.';
    }
    return null;
  }

  String? _validateBirthDate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Ingresá la fecha de nacimiento.';
    final date = parseUiDate(text);
    if (date == null) {
      return 'Escribí la fecha como día/mes/año, por ejemplo 15/03/1978.';
    }
    final today = UruguayTime.today();
    if (date.isAfter(DateTime(today.year, today.month, today.day))) {
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

  Future<void> _pickBirthDate() async {
    final today = UruguayTime.today();
    final last = DateTime(today.year, today.month, today.day);
    final initial = parseUiDate(_birthDateController.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial != null && !initial.isAfter(last) ? initial : last,
      firstDate: DateTime(_firstYear),
      lastDate: last,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null || !mounted) return;
    _birthDateController.text = _uiDate.format(picked);
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
    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
    final formValid = _formKey.currentState?.validate() ?? false;
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
            ci: normalizeCi(_ciController.text.trim())!,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            birthDate: parseUiDate(_birthDateController.text)!,
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
          TextFormField(
            controller: _ciController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Cédula de identidad',
              helperText: 'Con el dígito verificador, por ejemplo 1.234.567-2',
            ),
            validator: _validateCi,
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
          TextFormField(
            controller: _birthDateController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Fecha de nacimiento (dd/mm/aaaa)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                tooltip: 'Elegir fecha de nacimiento',
                onPressed: enabled ? _pickBirthDate : null,
              ),
            ),
            validator: _validateBirthDate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone1Controller,
            enabled: enabled,
            autovalidateMode: _autovalidate,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Teléfono 1'),
            validator: (v) => _required(v, 'Ingresá un teléfono.'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone2Controller,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Teléfono 2 (opcional)',
            ),
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
