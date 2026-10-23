package uy.edu.proyecto.backend.agenda;

import java.util.List;

public record AgendaOperativaPageResponse(
        List<AgendaOperativaDTO> items,
        int page,
        int size,
        long total
) {
}
