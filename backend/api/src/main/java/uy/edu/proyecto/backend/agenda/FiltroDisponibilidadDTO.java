package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;

public record FiltroDisponibilidadDTO(
        Long especialidadId,
        Long medicoId,
        LocalDate fechaDesde,
        LocalDate fechaHasta,
        String orden,
        String sentido
) {
}
