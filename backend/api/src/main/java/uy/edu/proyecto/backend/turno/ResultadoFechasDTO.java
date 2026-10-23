package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

public record ResultadoFechasDTO(
        List<TurnoProcesado> turnos,
        int consultasCanceladas
) {
    public record TurnoProcesado(Long turnoId, LocalDate fecha) {
    }
}
