package uy.edu.proyecto.backend.agenda;

import java.time.OffsetDateTime;

public record CancelacionDTO(
        Long consultaId,
        String estado,
        OffsetDateTime canceladaEn,
        boolean paseDevuelto
) {
}
