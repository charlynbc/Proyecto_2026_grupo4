package uy.edu.proyecto.backend.profesional;

import java.time.OffsetDateTime;

public record HorarioDisponible(
        Long id,
        Long profesionalId,
        OffsetDateTime inicio,
        OffsetDateTime fin
) {
}