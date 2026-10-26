package uy.edu.proyecto.backend.estadistica;

import java.time.LocalDate;
import java.util.List;

public record EstadisticaEspecialidadResponse(
        LocalDate desde,
        LocalDate hasta,
        List<EstadisticaEspecialidadDTO> items
) {
}
