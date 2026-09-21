package uy.edu.proyecto.backend.reserva;

import java.time.OffsetDateTime;

public record ReservaHistorial(
        Long id,
        String estado,
        OffsetDateTime fechaCreacion,
        OffsetDateTime fechaCancelacion,
        Long horarioId,
        OffsetDateTime inicio,
        OffsetDateTime fin,
        Long profesionalId,
        String profesional
) {
}