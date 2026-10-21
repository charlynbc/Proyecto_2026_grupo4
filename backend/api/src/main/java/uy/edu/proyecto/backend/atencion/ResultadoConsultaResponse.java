package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import uy.edu.proyecto.backend.especialidad.Especialidad;

public record ResultadoConsultaResponse(
        Long consultaId,
        String estado,
        Long atencionId,
        OffsetDateTime registradoEn,
        List<PaseDTO> pases
) {
    public record PaseDTO(
            Long id,
            Especialidad especialidadDestino,
            OffsetDateTime emitidoEn,
            LocalDate venceEl
    ) {
    }
}
