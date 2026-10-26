package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import uy.edu.proyecto.backend.especialidad.Especialidad;

public record HistoriaClinicaDTO(
        Long idAtencion,
        LocalDate fechaAtencion,
        Long medicoId,
        String medicoNombre,
        String medicoApellido,
        Especialidad especialidad,
        String afeccion,
        String tratamiento,
        String observaciones,
        List<PaseClinicaDTO> pases
) {
    public record PaseClinicaDTO(
            Long id,
            Especialidad especialidad,
            OffsetDateTime emitidoEn,
            LocalDate venceEl
    ) {
    }
}
