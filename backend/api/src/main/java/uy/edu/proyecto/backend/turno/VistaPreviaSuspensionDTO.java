package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

public record VistaPreviaSuspensionDTO(
        List<FechaAfectada> fechasAfectadas,
        int cantidadConsultasACancelar
) {
    public record FechaAfectada(
            Long turnoId,
            LocalDate fecha,
            String horaInicio,
            String horaFin,
            int consultasACancelar
    ) {
    }
}
