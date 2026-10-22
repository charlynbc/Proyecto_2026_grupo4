package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;

public record ConsultaHistorialFiltro(
        String estado,
        LocalDate fechaDesde,
        LocalDate fechaHasta,
        Long especialidadId,
        Long medicoId,
        String orden,
        String sentido,
        int page,
        int size
) {
}
