package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;

public record FiltroAgendaDTO(
        String ci,
        Long consultaId,
        LocalDate fecha,
        Long medicoId,
        String estado,
        Boolean llegada,
        String orden,
        String sentido,
        int page,
        int size
) {
}
