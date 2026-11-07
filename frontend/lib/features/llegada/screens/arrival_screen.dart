import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/centered_content.dart';
import '../../agenda/models/appointment.dart';
import '../../auth/widgets/credential_fields.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/arrival.dart';
import '../providers/arrival_providers.dart';

/// Pantalla del funcionario para registrar que un socio llegó a la ventanilla
/// (RF-16): busca por cédula, muestra sus consultas agendadas de hoy y
/// registra el aviso de llegada.
class ArrivalScreen extends ConsumerStatefulWidget {
  const ArrivalScreen({super.key});

  @override
  ConsumerState<ArrivalScreen> createState() => _ArrivalScreenState();
}

class _ArrivalScreenState extends ConsumerState<ArrivalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ciController = TextEditingController();

  /// La cédula de la última búsqueda: el registro usa esta, no lo que haya
  /// quedado escrito en el campo.
  String? _searchedCi;
  List<Appointment>? _appointments;
  String? _searchError;
  bool _searching = false;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _ciController.addListener(_clearStaleResult);
  }

  @override
  void dispose() {
    _ciController.dispose();
    super.dispose();
  }

  /// Si el campo ya no dice la cédula buscada, el resultado es de otro socio:
  /// se borra para no registrar la llegada de quien no corresponde. Se compara
  /// el texto porque el controlador también avisa cuando solo se mueve el
  /// cursor.
  void _clearStaleResult() {
    if (_searchedCi != null && _ciController.text != _searchedCi) {
      setState(() {
        _searchedCi = null;
        _appointments = null;
      });
    }
  }

  Future<void> _search() async {
    if (_searching || !_formKey.currentState!.validate()) return;
    final ci = _ciController.text;
    setState(() {
      _searching = true;
      _searchedCi = null;
      _appointments = null;
      _searchError = null;
    });
    try {
      final repository = await ref.read(arrivalRepositoryProvider.future);
      final appointments = await repository.listTodayAppointments(ci);
      if (!mounted) return;
      setState(() {
        _searchedCi = ci;
        _appointments = appointments;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = apiMessageOf(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _register() async {
    final ci = _searchedCi;
    // Se marca antes del primer await: un segundo toque no hace otro pedido.
    if (_registering || ci == null) return;
    setState(() => _registering = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await ref.read(arrivalRepositoryProvider.future);
      final result = await repository.registerArrival(ci);
      messenger.showSnackBar(SnackBar(content: Text(_resultMessage(result))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiMessageOf(e))));
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  String _resultMessage(ArrivalResult result) {
    final arrival = result.arrival;
    if (result.created) {
      return 'Llegada registrada a las ${arrival.registeredTime}.';
    }
    return 'La llegada ya estaba registrada a las ${arrival.registeredTime}. '
        'La registró ${arrival.registeredByName}.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointments = _appointments;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Llegada'),
        actions: const [LogoutButton()],
      ),
      body: CenteredContent(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Buscá al socio por su cédula para ver sus consultas de hoy y '
              'registrar que llegó.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: CiFormField(
                controller: _ciController,
                enabled: !_searching,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _searching ? null : _search,
              child: const Text('Buscar'),
            ),
            if (_searching) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_searchError != null) ...[
              const SizedBox(height: 24),
              Text(
                _searchError!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (appointments != null) ...[
              const SizedBox(height: 24),
              Text('Consultas de hoy', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (appointments.isEmpty)
                const Text(
                  'El socio no tiene consultas agendadas para hoy, así que no '
                  'se puede registrar su llegada.',
                )
              else
                for (final appointment in appointments)
                  _TodayAppointmentCard(appointment: appointment),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: appointments.isEmpty || _registering
                    ? null
                    : _register,
                child: const Text('Registrar llegada'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una consulta de hoy: hora, médico, especialidad y consultorio.
class _TodayAppointmentCard extends StatelessWidget {
  const _TodayAppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          '${appointment.timeRange} · ${appointment.doctor.fullName}',
        ),
        subtitle: Text(
          '${appointment.specialty.name} · ${appointment.clinic.name} '
          '(${appointment.clinic.location})',
        ),
      ),
    );
  }
}
