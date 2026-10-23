package uy.edu.proyecto.backend.turno;

import java.util.List;

public record RehabilitarFechasRequest(
        FiltroFechasRequest filtro,
        List<Long> ids
) {
}
