import 'package:agenda_medica/features/consultorios/natural_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3 va antes que 12', () {
    expect(compareNatural('3', '12'), lessThan(0));
  });

  test('Consultorio 2 va antes que Consultorio 10', () {
    expect(compareNatural('Consultorio 2', 'Consultorio 10'), lessThan(0));
  });

  test('mayusculas y minusculas se tratan igual', () {
    expect(compareNatural('consultorio 3', 'Consultorio 7'), lessThan(0));
    expect(compareNatural('Consultorio 3', 'consultorio 3'), 0);
  });

  test('sin numeros queda el orden alfabetico', () {
    expect(compareNatural('ala norte', 'ala sur'), lessThan(0));
  });

  test('textos iguales conservan el orden de llegada', () {
    final sorted = sortedNaturally([
      'primero',
      'segundo',
      'tercero',
      'cuarto',
    ], (_) => 'Consultorio 2');

    expect(sorted, ['primero', 'segundo', 'tercero', 'cuarto']);
  });
}
