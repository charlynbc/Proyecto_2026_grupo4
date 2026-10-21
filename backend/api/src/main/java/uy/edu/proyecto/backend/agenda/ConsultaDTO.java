package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.OffsetDateTime;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

public record ConsultaDTO(
        Long id,
        String estado,
        LocalDate fecha,
        int numero,
        String horaInicio,
        String horaFin,
        MedicoRef medico,
        Especialidad especialidad,
        Consultorio consultorio,
        Long paseId,
        OffsetDateTime agendadaEn,
        OffsetDateTime canceladaEn,
        String motivoCancelacion
) {
    public record MedicoRef(
            Long id,
            String nombre,
            String apellido
    ) {
    }
}
