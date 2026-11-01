package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;

public record CancelacionTurnoMedicoDTO(
        Long turnoId,
        LocalDate fecha,
        String estado,
        int consultasCanceladas,
        int pasesDevueltos
) {
}
