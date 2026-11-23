import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_date.dart';
import '../../../core/utils/ui_time.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../../core/widgets/ui_time_field.dart';
import '../providers/announcements_provider.dart';

/// Los cuatro textos de "Visible desde" y "Visible hasta" (fecha y hora de cada
/// uno), y lo que se necesita para validarlos y leerlos como instantes.
class AnnouncementVisibilityController {
  final fromDate = TextEditingController();
  final fromTime = TextEditingController();
  final untilDate = TextEditingController();
  final untilTime = TextEditingController();

  /// Mientras es `true`, los campos informan también los textos a medias. Lo
  /// pone quien valida el formulario, solo durante `validate()`.
  bool validating = false;

  /// El instante de inicio, o `null` si la fecha o la hora no están completas
  /// y válidas.
  DateTime? get from => _instant(fromDate, fromTime);

  /// El instante de fin, o `null` si la fecha o la hora no están completas y
  /// válidas.
  DateTime? get until => _instant(untilDate, untilTime);

  /// Escribe los textos a partir de instantes ya guardados, en hora de
  /// Uruguay. Sin inicio o sin fin deja vacío ese par.
  void fill({DateTime? from, DateTime? until}) {
    _write(fromDate, fromTime, from);
    _write(untilDate, untilTime, until);
  }

  void dispose() {
    fromDate.dispose();
    fromTime.dispose();
    untilDate.dispose();
    untilTime.dispose();
  }

  static DateTime? _instant(
    TextEditingController date,
    TextEditingController time,
  ) {
    final day = parseUiDate(date.text.trim());
    final hour = parseUiTime(time.text.trim());
    if (day == null || hour == null) return null;
    return UruguayTime.fromUruguay(day, hour.hour, hour.minute);
  }

  static void _write(
    TextEditingController date,
    TextEditingController time,
    DateTime? instant,
  ) {
    if (instant == null) {
      date.clear();
      time.clear();
      return;
    }
    final local = UruguayTime.toUruguay(instant);
    date.text = formatUiDate(DateTime.utc(local.year, local.month, local.day));
    time.text = formatUiTime(local.hour, local.minute);
  }
}

/// "Cuándo se ve": inicio opcional y fin obligatorio, cada uno con fecha y hora
/// de 24 h. Sirve dentro de un `Form`. Al elegir una fecha sin hora propone 00:00
/// para el inicio y 23:59 para el fin.
class AnnouncementVisibilityFields extends ConsumerWidget {
  const AnnouncementVisibilityFields({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onEdited,
  });

  final AnnouncementVisibilityController controller;
  final bool enabled;

  /// Se llama cuando alguien cambia cualquiera de los cuatro campos.
  final VoidCallback? onEdited;

  String? _requireDate(String? value, TextEditingController time) =>
      (value ?? '').trim().isEmpty && time.text.trim().isNotEmpty
      ? 'Elegí la fecha.'
      : null;

  String? _requireTime(String? value, TextEditingController date) =>
      (value ?? '').trim().isEmpty && date.text.trim().isNotEmpty
      ? 'Elegí la hora.'
      : null;

  /// Fecha y hora lado a lado si hay lugar, y una abajo de la otra si no.
  Widget _pair({
    required DateTime today,
    required String name,
    required TextEditingController date,
    required TextEditingController time,
    required String defaultTime,
    DateTime? Function()? suggestedDay,
  }) {
    final dateField = UiDateField(
      controller: date,
      label: '$name: fecha',
      pickerHelpText: 'Elegí la fecha ($name)',
      pickerTooltip: 'Elegir la fecha ($name)',
      firstDate: today,
      lastDate: DateTime.utc(today.year + 5, today.month, today.day),
      initialPickerDate: suggestedDay,
      today: () => today,
      enabled: enabled,
      showErrorsNow: () => controller.validating,
      validator: (value) => _requireDate(value, time),
      onChanged: (day) {
        if (day != null && time.text.trim().isEmpty) {
          time.text = defaultTime;
        } else if (date.text.trim().isEmpty &&
            time.text.trim() == defaultTime) {
          // Se vació la fecha: la hora que se puso sola ya no tiene sentido.
          // Una hora escrita a mano se conserva.
          time.clear();
        }
        onEdited?.call();
      },
    );
    final parts = defaultTime.split(':');
    final timeField = UiTimeField(
      controller: time,
      label: '$name: hora',
      pickerHelpText: 'Elegí la hora ($name)',
      pickerTooltip: 'Elegir la hora ($name)',
      initialPickerTime: () =>
          (hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      enabled: enabled,
      showErrorsNow: () => controller.validating,
      validator: (value) => _requireTime(value, date),
      onChanged: (_) => onEdited?.call(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [dateField, const SizedBox(height: 12), timeField],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: dateField),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: timeField),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = UruguayTime.today(now: ref.read(announcementClockProvider)());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Cuándo se ve', style: Theme.of(context).textTheme.titleMedium),
        const Text(
          'La novedad se deja de ver en el minuto exacto del fin: '
          'si termina a las 18:30, a las 18:30 ya no aparece. '
          'El inicio es opcional; sin inicio se ve desde que se '
          'publica.',
        ),
        const SizedBox(height: 12),
        _pair(
          today: today,
          name: 'Visible desde',
          date: controller.fromDate,
          time: controller.fromTime,
          defaultTime: '00:00',
        ),
        const SizedBox(height: 12),
        _pair(
          today: today,
          name: 'Visible hasta',
          date: controller.untilDate,
          time: controller.untilTime,
          defaultTime: '23:59',
          suggestedDay: () => parseUiDate(controller.fromDate.text.trim()),
        ),
      ],
    );
  }
}
