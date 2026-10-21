/// Estado de una fecha concreta de un turno (`EstadoTurno` del contrato).
enum ShiftState {
  active('ACTIVO', 'Activa'),
  suspended('SUSPENDIDO', 'Suspendida');

  const ShiftState(this.apiValue, this.label);

  /// El valor que viaja en la API.
  final String apiValue;

  /// Cómo se muestra al funcionario.
  final String label;

  /// Lee el valor de la API. Uno desconocido tira `FormatException` en vez de
  /// clasificarse mal en silencio.
  static ShiftState fromApi(String value) {
    for (final state in values) {
      if (state.apiValue == value) return state;
    }
    throw FormatException('Estado de turno desconocido', value);
  }
}
