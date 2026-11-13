import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/sort_direction_button.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../auth/widgets/logout_button.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/doctor_attention_query.dart';
import '../providers/doctor_attentions_provider.dart';
import 'doctor_attention_routes.dart';

class DoctorAttentionsScreen extends ConsumerStatefulWidget {
  const DoctorAttentionsScreen({super.key});
  @override
  ConsumerState<DoctorAttentionsScreen> createState() =>
      _DoctorAttentionsScreenState();
}

class _DoctorAttentionsScreenState
    extends ConsumerState<DoctorAttentionsScreen> {
  late final TextEditingController fromController;
  late final TextEditingController toController;
  final formKey = GlobalKey<FormState>();
  final patient = TextEditingController();
  int? specialtyId;
  DoctorAttentionOrder order = DoctorAttentionOrder.date;
  DoctorAttentionDirection direction = DoctorAttentionDirection.descending;

  /// El aviso de que Desde es posterior a Hasta; se muestra en el campo Hasta.
  String? rangeError;

  /// Mientras se valida el envío, una fecha a medias avisa aunque tenga foco.
  bool validating = false;

  /// El ancho de cada campo de fecha cuando entran los dos en una fila; con
  /// menos lugar, cada uno ocupa todo el ancho.
  static const double dateFieldWidth = 220;
  static const double dateFieldsRowWidth = 2 * dateFieldWidth + 8;

  @override
  void initState() {
    super.initState();
    // Los campos muestran las fechas aplicadas: al abrir, el mes en curso.
    final applied = ref.read(doctorAttentionFiltersProvider);
    fromController = TextEditingController(text: formatUiDate(applied.from));
    toController = TextEditingController(text: formatUiDate(applied.to));
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    patient.dispose();
    super.dispose();
  }

  void clearRangeError() {
    if (rangeError != null) setState(() => rangeError = null);
  }

  String? requiredDate(String? value) =>
      (value ?? '').trim().isEmpty ? 'Ingresá la fecha.' : null;

  void search() {
    // Tocar "Buscar" no mueve el foco del campo de fecha: se lo suelta acá
    // para que el campo muestre su error si la fecha quedó a medias.
    FocusScope.of(context).unfocus();
    validating = true;
    final valid = formKey.currentState!.validate();
    validating = false;
    if (!valid) return;
    final from = parseUiDate(fromController.text.trim())!;
    final to = parseUiDate(toController.text.trim())!;
    if (from.isAfter(to)) {
      setState(
        () => rangeError =
            'La fecha "Desde" no puede ser posterior a la fecha "Hasta".',
      );
      return;
    }
    setState(() => rangeError = null);
    ref
        .read(doctorAttentionFiltersProvider.notifier)
        .apply(
          DoctorAttentionQuery(
            from: from,
            to: to,
            patientText: patient.text,
            specialtyId: specialtyId,
            order: order,
            direction: direction,
          ),
        );
  }

  /// El orden y el sentido se aplican al instante, con los filtros que ya
  /// estaban aplicados: lo escrito sin tocar "Buscar" no se toca.
  void sort() {
    ref.read(doctorAttentionFiltersProvider.notifier).sortBy(order, direction);
  }

  void clear() {
    ref.read(doctorAttentionFiltersProvider.notifier).clear();
    final q = ref.read(doctorAttentionFiltersProvider);
    // reset vacía los campos y puede avisar el cambio: se hace antes de
    // escribir las fechas del mes en curso.
    formKey.currentState!.reset();
    fromController.text = formatUiDate(q.from);
    toController.text = formatUiDate(q.to);
    patient.clear();
    setState(() {
      specialtyId = null;
      order = q.order;
      direction = q.direction;
      rangeError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(doctorAttentionsProvider);
    final specialties = ref.watch(specialtiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atenciones'),
        actions: const [LogoutButton()],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Form(
                  key: formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth < dateFieldsRowWidth
                          ? constraints.maxWidth
                          : dateFieldWidth;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: [
                          SizedBox(
                            width: width,
                            child: UiDateField(
                              key: const Key('attentions-from'),
                              controller: fromController,
                              label: 'Desde',
                              pickerHelpText: 'Fecha desde',
                              pickerTooltip: 'Elegir la fecha desde',
                              firstDate: DateTime.utc(1900),
                              lastDate: DateTime.utc(2100),
                              showErrorsNow: () => validating,
                              validator: requiredDate,
                              onChanged: (_) => clearRangeError(),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: UiDateField(
                              key: const Key('attentions-to'),
                              controller: toController,
                              label: 'Hasta',
                              pickerHelpText: 'Fecha hasta',
                              pickerTooltip: 'Elegir la fecha hasta',
                              firstDate: DateTime.utc(1900),
                              lastDate: DateTime.utc(2100),
                              // El calendario de "Hasta" abre en la fecha de
                              // "Desde", si es válida.
                              initialPickerDate: () =>
                                  parseUiDate(fromController.text),
                              errorText: rangeError,
                              showErrorsNow: () => validating,
                              validator: requiredDate,
                              onChanged: (_) => clearRangeError(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                TextField(
                  key: const Key('attentions-patient-field'),
                  controller: patient,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Paciente (CI o apellido)',
                  ),
                ),
                specialties.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Row(
                    children: [
                      Expanded(child: Text(apiMessageOf(e))),
                      TextButton(
                        onPressed: () => ref.invalidate(specialtiesProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                  data: (values) {
                    final sorted = [...values]
                      ..sort((a, b) => a.name.compareTo(b.name));
                    return DropdownButton<int>(
                      key: const Key('attentions-specialty'),
                      value: specialtyId ?? 0,
                      isExpanded: true,
                      hint: const Text('Especialidad'),
                      items: [
                        const DropdownMenuItem<int>(
                          value: 0,
                          child: Text('Todas'),
                        ),
                        for (final s in sorted)
                          DropdownMenuItem<int>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => specialtyId = v == 0 ? null : v),
                    );
                  },
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<DoctorAttentionOrder>(
                      key: const Key('attentions-order'),
                      value: order,
                      items: const [
                        DropdownMenuItem(
                          value: DoctorAttentionOrder.date,
                          child: Text('Fecha'),
                        ),
                        DropdownMenuItem(
                          value: DoctorAttentionOrder.patientLastName,
                          child: Text('Apellido del paciente'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => order = v);
                          sort();
                        }
                      },
                    ),
                    SortDirectionButton(
                      key: const Key('attentions-direction'),
                      ascending:
                          direction == DoctorAttentionDirection.ascending,
                      onPressed: () {
                        setState(
                          () => direction =
                              direction == DoctorAttentionDirection.ascending
                              ? DoctorAttentionDirection.descending
                              : DoctorAttentionDirection.ascending,
                        );
                        sort();
                      },
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('attentions-search'),
                      onPressed: search,
                      child: const Text('Buscar'),
                    ),
                    TextButton(
                      key: const Key('attentions-clear'),
                      onPressed: clear,
                      child: const Text('Limpiar'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                items.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(apiMessageOf(e)),
                      OutlinedButton(
                        key: const Key('attentions-retry'),
                        onPressed: () =>
                            ref.invalidate(doctorAttentionsProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                  data: (list) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        list.length == 1
                            ? '1 atención'
                            : '${list.length} atenciones',
                      ),
                      if (list.isEmpty)
                        const Text(
                          'No hay atenciones que coincidan con los filtros.',
                          key: Key('attentions-empty'),
                        ),
                      for (final a in list)
                        Card(
                          child: ListTile(
                            key: Key('attention-${a.id}'),
                            title: Text(
                              '${a.patient.fullName} · CI ${a.patient.ci}',
                            ),
                            subtitle: Text(
                              '${formatUiDate(a.attendedOn)} · ${a.specialty.name} · ${a.condition}',
                            ),
                            onTap: () =>
                                context.push(doctorAttentionLocation(a.id)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
