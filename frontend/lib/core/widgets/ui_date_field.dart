import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../forms/early_field_validation.dart';
import '../utils/ui_date.dart';
import '../utils/uruguay_time.dart';

const int _dateLength = 10;

/// Un campo para escribir una fecha como `dd/mm/aaaa`, con un calendario para
/// elegirla y una cruz para borrarla.
///
/// - Solo acepta dígitos y barras, hasta 10 caracteres. No agrega las barras.
/// - El error de formato (o de una fecha que no existe) aparece al completar
///   los 10 caracteres o al salir del campo, no al primer carácter: sigue el
///   patrón de [EarlyFieldValidation]. Un campo vacío no tiene error; reclamar
///   que sea obligatorio es de quien lo usa, con su [validator].
/// - Las fechas son claves de día en UTC, como las de `UruguayTime`.
///
/// Sirve dentro de un `Form` (con [validator]) y suelto (con [errorText]).
class UiDateField extends StatefulWidget {
  const UiDateField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = 'dd/mm/aaaa',
    required this.pickerHelpText,
    required this.pickerTooltip,
    required this.firstDate,
    required this.lastDate,
    this.initialPickerDate,
    this.focusNode,
    this.enabled = true,
    this.errorText,
    this.validator,
    this.showErrorsNow,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.errorMaxLines = 4,
    this.today = UruguayTime.today,
  });

  /// El texto del campo. Lo maneja quien lo usa.
  final TextEditingController controller;

  final String label;
  final String hint;

  /// El título del calendario.
  final String pickerHelpText;

  /// El tooltip del ícono que abre el calendario.
  final String pickerTooltip;

  /// El rango que admite el calendario, como claves de día en UTC.
  final DateTime firstDate;
  final DateTime lastDate;

  /// La fecha con que abre el calendario si lo escrito no es una fecha válida.
  /// Se evalúa al abrir, no al armar el campo. Por ejemplo, para "Hasta", la
  /// fecha de "Desde" si es válida.
  final ValueGetter<DateTime?>? initialPickerDate;

  /// Si se pasa, quien lo usa lo maneja (y no cambia entre reconstrucciones).
  final FocusNode? focusNode;

  final bool enabled;

  /// Un error puesto desde afuera, para usarlo sin `Form`.
  final String? errorText;

  /// Se corre después de las reglas de formato, y solo con el campo vacío o con
  /// una fecha válida. Con el campo vacío es donde se reclama que sea
  /// obligatorio.
  final FormFieldValidator<String>? validator;

  /// Mientras devuelve `true`, el campo informa su error de formato aunque la
  /// fecha esté a medias o tenga el foco. Es para el formulario que valida el
  /// envío: soltar el foco no es inmediato (el `FocusManager` lo aplica en un
  /// microtask), así que sin esto una fecha a medias pasaría por válida.
  final ValueGetter<bool>? showErrorsNow;

  /// Avisa la fecha cuando el texto es una fecha válida y `null` cuando está
  /// vacío o no lo es. Se llama al escribir, al elegir en el calendario y al
  /// borrar.
  final ValueChanged<DateTime?>? onChanged;

  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final int errorMaxLines;

  /// Hoy, para la fecha con que abre el calendario cuando no hay otra. Se
  /// puede reemplazar en pruebas para no depender del reloj.
  final DateTime Function() today;

  @override
  State<UiDateField> createState() => _UiDateFieldState();
}

class _UiDateFieldState extends State<UiDateField> {
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
      completeLength: _dateLength,
      check: uiDateError,
    );
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(UiDateField oldWidget) {
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
        ? uiDateError((value ?? '').trim())
        : _early.validate(value);
    if (early != null) return early;
    final text = (value ?? '').trim();
    final custom = widget.validator;
    if (custom == null) return null;
    // Con el texto a medias o con una fecha que no existe, el error es de
    // formato y no tiene sentido sumarle otra regla.
    if (text.isNotEmpty && parseUiDate(text) == null) return null;
    return custom(value);
  }

  void _onTextChanged(String text) {
    widget.onChanged?.call(parseUiDate(text));
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call(null);
    _focusNode.requestFocus();
  }

  /// `showDatePicker` trabaja con fechas locales.
  static DateTime _local(DateTime key) =>
      DateTime(key.year, key.month, key.day);

  Future<void> _pick() async {
    final first = _local(widget.firstDate);
    final last = _local(widget.lastDate);
    // Lo escrito si es válido; si no, la fecha que sugiera quien lo usa; si
    // no, hoy. Siempre dentro del rango: `showDatePicker` falla si no.
    var initial = _local(
      parseUiDate(widget.controller.text) ??
          widget.initialPickerDate?.call() ??
          widget.today(),
    );
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: widget.pickerHelpText,
      // Explícitos: el "ACEPTAR" nativo de es_UY va en mayúsculas.
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null || !mounted) return;
    final date = DateTime.utc(picked.year, picked.month, picked.day);
    widget.controller.text = formatUiDate(date);
    widget.onChanged?.call(date);
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
        FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
        LengthLimitingTextInputFormatter(_dateLength),
      ],
      textInputAction: widget.textInputAction,
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
                tooltip: 'Borrar la fecha',
                visualDensity: VisualDensity.compact,
                onPressed: _clear,
              ),
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              tooltip: widget.pickerTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: widget.enabled ? _pick : null,
            ),
          ],
        ),
      ),
      validator: _validate,
      onChanged: _onTextChanged,
      onFieldSubmitted: widget.onSubmitted,
    );
  }
}
