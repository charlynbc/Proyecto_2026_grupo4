package uy.edu.proyecto.backend.agenda;

import java.util.List;

public record ConsultaHistorialPageResponse(
        List<ConsultaDTO> items,
        int page,
        int size,
        long total
) {
}
