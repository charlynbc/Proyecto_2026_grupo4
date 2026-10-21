import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/validators/uruguayan_ci_validator.dart';

/// Campo de cédula: solo dígitos (sin puntos ni guiones), con el dígito
/// verificador incluido. La validación definitiva es del servidor.
class CiFormField extends StatelessWidget {
  const CiFormField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autovalidateMode,
    this.focusNode,
    this.validator = validate,
  });

  final TextEditingController controller;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;

  /// Por defecto [validate]; el login usa uno que espera a que se termine de
  /// escribir.
  final FormFieldValidator<String> validator;

  static String? validate(String? value) {
    final ci = value?.trim() ?? '';
    if (ci.isEmpty) return 'Ingresá tu cédula.';
    if (!isValidUruguayanCi(ci)) {
      return 'La cédula no es válida. Escribila completa, con el dígito '
          'verificador, sin puntos ni guiones.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      decoration: const InputDecoration(
        labelText: 'Cédula de identidad',
        hintText: 'Sin puntos ni guiones',
        // El mensaje de cédula inválida es largo: sin esto se corta con "…".
        errorMaxLines: 3,
      ),
      validator: validator,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
    );
  }
}

/// Campo de contraseña con botón para mostrarla u ocultarla.
class PasswordFormField extends StatefulWidget {
  const PasswordFormField({
    super.key,
    required this.controller,
    required this.validator,
    this.label = 'Contraseña',
    this.hint,
    this.enabled = true,
    this.autovalidateMode,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final String label;
  final String? hint;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      enabled: widget.enabled,
      onFieldSubmitted: widget.onSubmitted,
    );
  }
}
