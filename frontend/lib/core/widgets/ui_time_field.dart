import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../forms/early_field_validation.dart';
import '../utils/ui_time.dart';

const int _timeLength = 5;

/// Un campo para escribir una hora como `HH:mm` de 24 horas, con un selector
/// para elegirla y una cruz para borrarla.
///
/// - Solo acepta dígitos y dos puntos, hasta 5 caracteres.
/// - El error de formato (o de una hora que no existe, como 24:00) aparece al
///   completar los 5 caracteres o al salir del campo, no al primer carácter:
///   sigue el patrón de [EarlyFieldValidation]. Un campo vacío no tiene error;
///   reclamar que sea obligatorio es de quien lo usa, con su [validator].
/// - El selector es siempre de 24 horas, sin AM ni PM.
///
/// Sirve dentro de un `Form` (con [validator]) y suelto (con [errorText]).
class UiTimeField extends StatefulWidget {
  const UiTimeField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = 'HH:mm',
    required this.pickerHelpText,
    required this.pickerTooltip,
    this.initialPickerTime,
    this.focusNode,
    this.enabled = true,
    this.errorText,
    this.validator,
    this.showErrorsNow,
    this.onChanged,
    this.errorMaxLines = 4,
  });

  /// El texto del campo. Lo maneja quien lo usa.
  final TextEditingController controller;

  final String label;
  final String hint;

  /// El título del selector.
  final String pickerHelpText;

  /// El tooltip del ícono que abre el selector.
  final String pickerTooltip;

  /// La hora con que abre el selector si lo escrito no es una hora válida. Se
  /// evalúa al abrir. Sin esto abre en 00:00.
  final ValueGetter<({int hour, int minute})?>? initialPickerTime;

  /// Si se pasa, quien lo usa lo maneja (y no cambia entre reconstrucciones).
  final FocusNode? focusNode;

  final bool enabled;

  /// Un error puesto desde afuera, para usarlo sin `Form`.
  final String? errorText;

  /// Se corre después de las reglas de formato, y solo con el campo vacío o con
  /// una hora válida. Con el campo vacío es donde se reclama que sea
  /// obligatorio.
  final FormFieldValidator<String>? validator;

  /// Mientras devuelve `true`, el campo informa su error de formato aunque la
  /// hora esté a medias o tenga el foco (para el formulario que valida el
  /// envío).
  final ValueGetter<bool>? showErrorsNow;

  /// Avisa la hora cuando el texto es una hora válida y `null` cuando está
  /// vacío o no lo es. Se llama al escribir, al elegir en el selector y al
  /// borrar.
  final ValueChanged<({int hour, int minute})?>? onChanged;

  final int errorMaxLines;

  @override
  State<UiTimeField> createState() => _UiTimeFieldState();
}

class _UiTimeFieldState extends State<UiTimeField> {
  FocusNode? _ownFocusNode;
  late final EarlyFieldValidation _early;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _early = EarlyFieldValidation(
      focusNode: _focusNode,
      emptyMessage: null,
      completeLength: _timeLength,
      check: uiTimeError,
    );
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(UiTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  /// El campo revalida cuando se reconstruye: sin esto no avisaría del error al
  /// perder el foco.
  void _rebuild() {
    if (mounted) setState(() {});
  }

  String? _validate(String? value) {
    final early = (widget.showErrorsNow?.call() ?? false)
        ? uiTimeError((value ?? '').trim())
        : _early.validate(value);
    if (early != null) return early;
    final text = (value ?? '').trim();
    final custom = widget.validator;
    if (custom == null) return null;
    // Con el texto a medias o con una hora que no existe, el error es de
    // formato y no tiene sentido sumarle otra regla.
    if (text.isNotEmpty && parseUiTime(text) == null) return null;
    return custom(value);
  }

  void _onTextChanged(String text) {
    widget.onChanged?.call(parseUiTime(text));
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call(null);
    _focusNode.requestFocus();
  }

  Future<void> _pick() async {
    final initial =
        parseUiTime(widget.controller.text) ??
        widget.initialPickerTime?.call() ??
        (hour: 0, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
      helpText: widget.pickerHelpText,
      // Explícitos: el "ACEPTAR" nativo de es_UY va en mayúsculas.
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      // Siempre de 24 horas, sin AM ni PM.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    widget.controller.text = formatUiTime(picked.hour, picked.minute);
    widget.onChanged?.call((hour: picked.hour, minute: picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final showClear = widget.enabled && widget.controller.text.isNotEmpty;
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      keyboardType: TextInputType.datetime,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
        LengthLimitingTextInputFormatter(_timeLength),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        errorMaxLines: widget.errorMaxLines,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showClear)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Borrar la hora',
                visualDensity: VisualDensity.compact,
                onPressed: _clear,
              ),
            IconButton(
              icon: const Icon(Icons.access_time),
              tooltip: widget.pickerTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: widget.enabled ? _pick : null,
            ),
          ],
        ),
      ),
      validator: _validate,
      onChanged: _onTextChanged,
    );
  }
}
