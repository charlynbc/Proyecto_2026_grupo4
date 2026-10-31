package uy.edu.proyecto.backend.pase;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import uy.edu.proyecto.backend.atencion.AtencionMedicaDTO;
import uy.edu.proyecto.backend.especialidad.Especialidad;

public record PaseEmitidoDTO(
        Long id,
        AtencionMedicaDTO.PacienteRef paciente,
        Especialidad especialidadDestino,
        OffsetDateTime emitidoEn,
        LocalDate venceEl,
        String situacion
) {
}
