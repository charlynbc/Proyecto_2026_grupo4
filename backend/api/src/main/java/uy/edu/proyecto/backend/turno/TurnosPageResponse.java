package uy.edu.proyecto.backend.turno;

import java.util.List;

public record TurnosPageResponse(
        List<TurnoFechaResponse> items,
        int page,
        int size,
        long total
) {
}
