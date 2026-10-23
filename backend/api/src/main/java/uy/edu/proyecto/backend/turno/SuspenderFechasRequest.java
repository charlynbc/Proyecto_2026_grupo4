package uy.edu.proyecto.backend.turno;

import java.util.List;

public record SuspenderFechasRequest(
        FiltroFechasRequest filtro,
        List<Long> ids,
        String observacion,
        Integer cantidadConfirmada
) {
}
