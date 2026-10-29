import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_locale.dart';
import '../../../core/network/api_exception.dart';
import '../models/doctor_shift.dart';
import '../providers/doctor_shifts_provider.dart';
import 'shift_routes.dart';

DateTime _normalizedDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _formatTime(String raw) {
  final trimmed = raw.trim();
  final parts = trimmed.split(':');
  if (parts.length < 2) return trimmed;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class DoctorShiftsScreen extends ConsumerStatefulWidget {
  const DoctorShiftsScreen({
    super.key,
    required this.date,
  });

  final DateTime date;

  @override
  ConsumerState<DoctorShiftsScreen> createState() => _DoctorShiftsScreenState();
}

class _DoctorShiftsScreenState extends ConsumerState<DoctorShiftsScreen> {
  Timer? _refreshTimer;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizedDate(widget.date);
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant DoctorShiftsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.date != oldWidget.date) {
      final nextDate = _normalizedDate(widget.date);
      if (nextDate != _selectedDate) {
        setState(() => _selectedDate = nextDate);
      }
      _startRefreshTimer();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.invalidate(doctorShiftsProvider(_selectedDate));
    });
  }

  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    final nextDate = _normalizedDate(picked);
    if (nextDate == _selectedDate) return;
    setState(() => _selectedDate = nextDate);
    ref.invalidate(doctorShiftsProvider(_selectedDate));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(doctorShiftsProvider(_selectedDate));
    final hasPreviousData = shiftsAsync.value != null;
    final shifts = shiftsAsync.value ?? const <DoctorShift>[];
    final errorMessage = shiftsAsync.hasError
        ? apiMessageOf(shiftsAsync.error!)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Turnos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yyyy', kAppLocale.toString())
                        .format(_selectedDate),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showDatePicker,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Elegir fecha'),
                ),
              ],
            ),
          ),
          if (shiftsAsync.hasError && hasPreviousData)
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
                    onPressed: () => ref.invalidate(doctorShiftsProvider(_selectedDate)),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          if (shiftsAsync.isLoading && !hasPreviousData)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (shiftsAsync.hasError && !hasPreviousData)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        errorMessage ?? 'No pudimos cargar los turnos. Intentá de nuevo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(doctorShiftsProvider(_selectedDate)),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (shifts.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No tenés turnos para esta fecha',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: shifts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final shift = shifts[index];
                  final isSuspended = shift.estado == 'SUSPENDIDO';
                  final occupation = '${shift.cantidadReservados} de ${shift.cantidadNumeros}';

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(doctorShiftDetailLocation(shift.id)),
                    child: Card(
                      color: isSuspended ? Colors.orange.shade50 : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    shift.especialidad.nombre,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                if (isSuspended)
                                  Chip(
                                    label: const Text('SUSPENDIDO'),
                                    backgroundColor: Colors.orange.shade200,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${shift.consultorio.nombre} · ${shift.consultorio.ubicacion}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_formatTime(shift.horaInicio)} - ${_formatTime(shift.horaFin)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ocupación'),
                                Text(
                                  occupation,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            ),
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
