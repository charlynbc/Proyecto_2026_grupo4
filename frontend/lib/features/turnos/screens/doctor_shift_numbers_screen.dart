import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_locale.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/uruguay_time.dart';
import '../models/doctor_shift_number.dart';
import '../providers/doctor_shift_numbers_provider.dart';
import 'shift_routes.dart';

String _formatTime(String raw) {
  final parts = raw.trim().split(':');
  if (parts.length < 2) return raw.trim();
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _consultationStatusLabel(String rawStatus) {
  switch (rawStatus.trim().toUpperCase()) {
    case 'AGENDADA':
      return 'Agendada';
    case 'ATENDIDA':
      return 'Atendida';
    case 'NO_PRESENTE':
    case 'NO_SE_PRESENTO':
    case 'NO SE PRESENTÓ':
    case 'NO SE PRESENTO':
    case 'NO_PRESENTADO':
      return 'No se presentó';
    default:
      return rawStatus.trim();
  }
}

class DoctorShiftNumbersScreen extends ConsumerStatefulWidget {
  const DoctorShiftNumbersScreen({
    super.key,
    required this.shiftId,
  });

  final int shiftId;

  @override
  ConsumerState<DoctorShiftNumbersScreen> createState() =>
      _DoctorShiftNumbersScreenState();
}

class _DoctorShiftNumbersScreenState
    extends ConsumerState<DoctorShiftNumbersScreen> {
  Timer? _refreshTimer;
  bool? _llegada;
  String _orden = 'hora';
  String _sentido = 'asc';

  late DoctorShiftNumbersParams _params;

  @override
  void initState() {
    super.initState();
    _params = DoctorShiftNumbersParams(
      shiftId: widget.shiftId,
      llegada: _llegada,
      orden: _orden,
      sentido: _sentido,
    );
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant DoctorShiftNumbersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shiftId != oldWidget.shiftId) {
      _params = DoctorShiftNumbersParams(
        shiftId: widget.shiftId,
        llegada: _llegada,
        orden: _orden,
        sentido: _sentido,
      );
      ref.invalidate(doctorShiftNumbersProvider(_params));
      _startRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(doctorShiftNumbersProvider(_params));
    });
  }

  void _applyFilter({
    bool? llegada,
    bool updateLlegada = false,
    String? orden,
    bool updateOrden = false,
    String? sentido,
    bool updateSentido = false,
  }) {
    final nextLlegada = updateLlegada ? llegada : _llegada;
    final nextOrden = updateOrden ? (orden ?? _orden) : _orden;
    final nextSentido = updateSentido ? (sentido ?? _sentido) : _sentido;
    final nextParams = DoctorShiftNumbersParams(
      shiftId: widget.shiftId,
      llegada: nextLlegada,
      orden: nextOrden,
      sentido: nextSentido,
    );
    if (nextParams == _params) return;
    setState(() {
      if (updateLlegada) {
        _llegada = llegada;
      }
      if (updateOrden) {
        _orden = orden ?? _orden;
      }
      if (updateSentido) {
        _sentido = sentido ?? _sentido;
      }
      _params = nextParams;
    });
    ref.invalidate(doctorShiftNumbersProvider(_params));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numbersAsync = ref.watch(doctorShiftNumbersProvider(_params));
    final hasPreviousData = numbersAsync.value != null;
    final response = numbersAsync.value;
    final items = response?.items ?? const <DoctorShiftNumber>[];
    final turno = response?.turno;
    final errorMessage = numbersAsync.hasError ? apiMessageOf(numbersAsync.error!) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Turno')),
      body: Column(
        children: [
          if (turno != null || numbersAsync.isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          turno?.especialidad.nombre ?? 'Turno',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (turno?.estado == 'SUSPENDIDO')
                        Chip(
                          label: const Text('SUSPENDIDO'),
                          backgroundColor: Colors.orange.shade200,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    turno != null
                        ? '${turno.consultorio.nombre} · ${turno.consultorio.ubicacion}'
                        : 'Consultorio',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    turno != null
                        ? DateFormat('dd/MM/yyyy', kAppLocale.toString())
                            .format(turno.fecha)
                        : 'Fecha',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<bool?>(
                    key: ValueKey('doctor-shift-llegada-${_llegada ?? 'todos'}'),
                    isExpanded: true,
                    initialValue: _llegada,
                    decoration: const InputDecoration(labelText: 'Llegada'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos')),
                      DropdownMenuItem(value: true, child: Text('Con llegada')),
                      DropdownMenuItem(value: false, child: Text('Sin llegada')),
                    ],
                    onChanged: (value) =>
                        _applyFilter(llegada: value, updateLlegada: true),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('doctor-shift-orden-$_orden'),
                    isExpanded: true,
                    initialValue: _orden,
                    decoration: const InputDecoration(labelText: 'Orden'),
                    items: const [
                      DropdownMenuItem(value: 'hora', child: Text('Hora')),
                      DropdownMenuItem(
                        value: 'horaLlegada',
                        child: Text('Hora de llegada'),
                      ),
                    ],
                    onChanged: (value) =>
                        _applyFilter(orden: value ?? _orden, updateOrden: true),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('doctor-shift-sentido-$_sentido'),
                    isExpanded: true,
                    initialValue: _sentido,
                    decoration: const InputDecoration(labelText: 'Sentido'),
                    items: const [
                      DropdownMenuItem(value: 'asc', child: Text('Asc')),
                      DropdownMenuItem(value: 'desc', child: Text('Desc')),
                    ],
                    onChanged: (value) =>
                        _applyFilter(sentido: value ?? _sentido, updateSentido: true),
                  ),
                ),
              ],
            ),
          ),
          if (numbersAsync.hasError && hasPreviousData)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No se pudo actualizar. Se sigue mostrando la última información.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(doctorShiftNumbersProvider(_params)),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          if (numbersAsync.isLoading && !hasPreviousData)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (numbersAsync.hasError && !hasPreviousData)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        errorMessage ?? 'No pudimos cargar los números.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(doctorShiftNumbersProvider(_params)),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final consultation = item.consulta;
                  final timeRange =
                      '${_formatTime(item.horaInicio)} - ${_formatTime(item.horaFin)}';

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: consultation != null
                        ? () => context.push(
                              doctorShiftConsultationLocation(consultation.id),
                            )
                        : null,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'N.º ${item.numero}',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                Text(timeRange),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (consultation != null) ...[
                              Text(
                                'Paciente: ${consultation.paciente.nombre} ${consultation.paciente.apellido}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Estado: ${_consultationStatusLabel(consultation.estado)}',
                              ),
                              const SizedBox(height: 4),
                              if (consultation.llegadaEn != null)
                                Text(
                                  'Llegada: ${DateFormat('HH:mm', kAppLocale.toString()).format(UruguayTime.toUruguay(consultation.llegadaEn!))}',
                                )
                              else
                                const Text('Llegada: Aún no llegó'),
                            ] else if (item.disponible) ...[
                              const Text('Disponible'),
                            ] else ...[
                              const Text('Sin reserva'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
