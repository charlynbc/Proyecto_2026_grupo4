import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
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
  late DoctorAttentionQuery initial;
  late DateTime from, to;
  final patient = TextEditingController();
  int? specialtyId;
  DoctorAttentionOrder order = DoctorAttentionOrder.date;
  DoctorAttentionDirection direction = DoctorAttentionDirection.descending;
  String? error;
  @override
  void initState() {
    super.initState();
    initial = DoctorAttentionQuery.initial();
    from = initial.from;
    to = initial.to;
  }

  @override
  void dispose() {
    patient.dispose();
    super.dispose();
  }

  Future<void> pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? from : to,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() {
        final date = DateTime.utc(selected.year, selected.month, selected.day);
        if (start) {
          from = date;
        } else {
          to = date;
        }
      });
    }
  }

  void search() {
    if (from.isAfter(to)) {
      setState(
        () => error = 'La fecha desde no puede ser posterior a la fecha hasta.',
      );
      return;
    }
    setState(() => error = null);
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

  void clear() {
    final q = DoctorAttentionQuery.initial();
    setState(() {
      from = q.from;
      to = q.to;
      patient.clear();
      specialtyId = null;
      order = q.order;
      direction = q.direction;
      error = null;
    });
    ref.read(doctorAttentionFiltersProvider.notifier).clear();
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('attentions-from'),
                      onPressed: () => pick(true),
                      child: Text('Desde ${formatUiDate(from)}'),
                    ),
                    OutlinedButton(
                      key: const Key('attentions-to'),
                      onPressed: () => pick(false),
                      child: Text('Hasta ${formatUiDate(to)}'),
                    ),
                  ],
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
                  loading: () => const CircularProgressIndicator(),
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
                          setState(() {
                            order = v;
                            direction = v == DoctorAttentionOrder.date
                                ? DoctorAttentionDirection.descending
                                : DoctorAttentionDirection.ascending;
                          });
                        }
                      },
                    ),
                    OutlinedButton(
                      key: const Key('attentions-direction'),
                      onPressed: () => setState(
                        () => direction =
                            direction == DoctorAttentionDirection.ascending
                            ? DoctorAttentionDirection.descending
                            : DoctorAttentionDirection.ascending,
                      ),
                      child: Text(
                        direction == DoctorAttentionDirection.ascending
                            ? 'Ascendente'
                            : 'Descendente',
                      ),
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
