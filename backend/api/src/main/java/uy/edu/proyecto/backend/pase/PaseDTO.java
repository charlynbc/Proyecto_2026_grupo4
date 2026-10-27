package uy.edu.proyecto.backend.pase;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import uy.edu.proyecto.backend.especialidad.Especialidad;

public record PaseDTO(
        Long id,
        Especialidad especialidadDestino,
        OffsetDateTime emitidoEn,
        LocalDate venceEl
) {
}
