package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;

public record FiltroTurnosDTO(
        Long medicoId,
        Long especialidadId,
        Integer diaSemana,
        LocalDate fechaDesde,
        LocalDate fechaHasta,
        String estado,
        String orden,
        String sentido,
        int page,
        int size
) {
}
