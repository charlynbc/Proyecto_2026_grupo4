package uy.edu.proyecto.backend.reserva;

import java.time.OffsetDateTime;

public record ReservaCancelada(
        Long id,
        Long horarioId,
        String estado,
        OffsetDateTime fechaCancelacion
) {
}