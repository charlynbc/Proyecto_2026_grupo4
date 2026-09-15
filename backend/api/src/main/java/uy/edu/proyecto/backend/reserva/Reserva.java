package uy.edu.proyecto.backend.reserva;

import java.time.OffsetDateTime;

public record Reserva(
        Long id,
        Long horarioId,
        String estado,
        OffsetDateTime fechaCreacion
) {
}
