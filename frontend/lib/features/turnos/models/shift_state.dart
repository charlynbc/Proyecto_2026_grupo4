/// Estado de una fecha concreta de un turno (`EstadoTurno` del contrato).
enum ShiftState {
  active('ACTIVO', 'Activa'),
  suspended('SUSPENDIDO', 'Suspendida');

  const ShiftState(this.apiValue, this.label);

  /// El valor que viaja en la API.
  final String apiValue;

  /// Cómo se muestra al funcionario.
  final String label;
}
