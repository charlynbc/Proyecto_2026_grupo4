import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/models/referral.dart';
import 'package:agenda_medica/features/agenda/providers/agenda_repository_provider.dart';
import 'package:agenda_medica/features/agenda/providers/available_referrals_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/agenda_repository.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cardiología, la del catálogo de los fakes (id 2).
const _cardiology = Specialty(
  id: 2,
  name: 'Cardiología',
  requiresReferral: true,
);

final _referrals = [
  Referral(
    id: 77,
    specialty: _cardiology,
    issuedAt: DateTime.utc(2026, 10, 20, 14, 30),
    expiresOn: DateTime.utc(2026, 11, 19),
  ),
  Referral(
    id: 78,
    specialty: _cardiology,
    issuedAt: DateTime.utc(2026, 10, 22, 14, 30),
    expiresOn: DateTime.utc(2026, 12, 1),
  ),
];

/// Devuelve [referrals] o falla con [error], y cuenta cuántas veces se le
/// pidió la lista de pases.
class _CountingAgendaRepository implements AgendaRepository {
  _CountingAgendaRepository({this.referrals = const [], this.error});

  final List<Referral> referrals;
  final Object? error;
  int listReferralsCalls = 0;

  @override
  Future<List<Referral>> listReferrals() async {
    listReferralsCalls++;
    if (error != null) throw error!;
    return referrals;
  }

  @override
  Future<List<AvailableNumber>> listAvailability(AvailabilityQuery query) =>
      throw UnimplementedError();

  @override
  Future<Appointment> book({required int numberId, int? referralId}) =>
      throw UnimplementedError();
}

ProviderContainer _container(WidgetTester tester, AgendaRepository repository) {
  final container = ProviderContainer(
    overrides: [
      agendaRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  testWidgets('con éxito entrega la lista de pases del repositorio', (
    tester,
  ) async {
    final repository = _CountingAgendaRepository(referrals: _referrals);
    final container = _container(tester, repository);
    container.listen(availableReferralsProvider, (_, _) {});

    await tester.pump(const Duration(milliseconds: 1));
    final state = container.read(availableReferralsProvider);

    expect(state, isA<AsyncData<List<Referral>>>());
    final referrals = state.requireValue;
    expect([for (final r in referrals) r.id], [77, 78]);
    expect(referrals[0].specialty.id, 2);
    expect(referrals[0].specialty.name, 'Cardiología');
    expect(referrals[0].expiresOn, DateTime.utc(2026, 11, 19));
    expect(referrals[1].expiresOn, DateTime.utc(2026, 12, 1));
    expect(repository.listReferralsCalls, 1);
  });

  // Riverpod 3 reintenta solo los providers que fallan (el primer reintento a
  // los 200 ms) y mientras tanto el estado es "cargando": el diálogo no
  // llegaría a mostrar el error. El provider de pases no debe reintentar.
  testWidgets('una falla del repositorio es un AsyncError enseguida y se '
      'pide una sola vez', (tester) async {
    final repository = _CountingAgendaRepository(
      error: const ApiException('No se pudieron cargar los pases de prueba.'),
    );
    final container = _container(tester, repository);
    container.listen(availableReferralsProvider, (_, _) {}, onError: (_, _) {});

    await tester.pump(const Duration(milliseconds: 1));
    final state = container.read(availableReferralsProvider);

    expect(state, isA<AsyncError<List<Referral>>>());
    expect(state.isLoading, isFalse);
    expect(state.retrying, isFalse);
    expect(repository.listReferralsCalls, 1);

    // Más tiempo que el primer reintento de Riverpod: no vuelve a pedir.
    await tester.pump(const Duration(seconds: 2));

    expect(container.read(availableReferralsProvider), isA<AsyncError>());
    expect(repository.listReferralsCalls, 1);
  });

  testWidgets('al soltar el provider y volver a leerlo se vuelve a pedir', (
    tester,
  ) async {
    final repository = _CountingAgendaRepository(referrals: _referrals);
    final container = _container(tester, repository);

    final first = container.listen(availableReferralsProvider, (_, _) {});
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.listReferralsCalls, 1);

    first.close();
    await tester.pump(const Duration(seconds: 1));

    container.listen(availableReferralsProvider, (_, _) {});
    await tester.pump(const Duration(milliseconds: 1));

    expect(repository.listReferralsCalls, 2);
    expect(
      container.read(availableReferralsProvider).requireValue,
      hasLength(2),
    );
  });
}
