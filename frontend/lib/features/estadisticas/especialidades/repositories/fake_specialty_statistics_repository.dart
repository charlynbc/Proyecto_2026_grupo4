import '../../../../core/utils/uruguay_time.dart';
import '../../../especialidades/models/specialty.dart';
import '../models/specialty_demand.dart';
import 'specialty_statistics_repository.dart';

/// Implementación en memoria para `USE_FAKES=true`. Devuelve siempre las
/// mismas cuatro especialidades, sin filtrar por fecha: solo repite el
/// período pedido (o el mes en curso del reloj si no se pidió ninguno).
class FakeSpecialtyStatisticsRepository
    implements SpecialtyStatisticsRepository {
  FakeSpecialtyStatisticsRepository({
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _clock;

  static const _items = [
    SpecialtyDemandItem(
      specialty: Specialty(
        id: 1,
        name: 'Medicina General',
        requiresReferral: false,
      ),
      count: 128,
    ),
    SpecialtyDemandItem(
      specialty: Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
      count: 42,
    ),
    SpecialtyDemandItem(
      specialty: Specialty(id: 4, name: 'Dermatología', requiresReferral: true),
      count: 7,
    ),
    SpecialtyDemandItem(
      specialty: Specialty(id: 2, name: 'Pediatría', requiresReferral: false),
      count: 0,
    ),
  ];

  @override
  Future<SpecialtyDemand> demand({DateTime? from, DateTime? to}) async {
    await Future<void>.delayed(latency);
    final now = UruguayTime.toUruguay(_clock());
    final start = from ?? DateTime.utc(now.year, now.month);
    final end = to ?? DateTime.utc(now.year, now.month + 1, 0);
    if (start.isAfter(end)) {
      throw const SpecialtyStatisticsException(
        SpecialtyStatisticsFailure.validation,
        'desde no puede ser posterior a hasta',
      );
    }
    return SpecialtyDemand(from: start, to: end, items: _items);
  }
}
