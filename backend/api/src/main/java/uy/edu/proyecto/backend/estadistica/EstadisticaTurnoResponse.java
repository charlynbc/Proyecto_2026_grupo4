package uy.edu.proyecto.backend.estadistica;

import java.time.LocalDate;
import java.util.List;

public record EstadisticaTurnoResponse(
        LocalDate desde,
        LocalDate hasta,
        List<EstadisticaTurnoDTO> items
) {
}
