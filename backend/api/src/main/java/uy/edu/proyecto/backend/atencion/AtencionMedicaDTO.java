package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.util.List;

import uy.edu.proyecto.backend.especialidad.Especialidad;

public record AtencionMedicaDTO(
        Long idAtencion,
        LocalDate fechaAtencion,
        PacienteRef paciente,
        Especialidad especialidad,
        String afeccion,
        String tratamiento,
        String observaciones,
        List<HistoriaClinicaDTO.PaseClinicaDTO> pases
) {
    public record PacienteRef(
            Long id,
            String ci,
            String nombre,
            String apellido
    ) {
    }
}
