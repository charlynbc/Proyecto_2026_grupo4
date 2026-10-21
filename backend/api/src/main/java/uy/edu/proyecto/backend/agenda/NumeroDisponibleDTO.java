package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

public record NumeroDisponibleDTO(
        Long numeroId,
        Long turnoId,
        int numero,
        LocalDate fecha,
        String horaInicio,
        String horaFin,
        MedicoRef medico,
        Especialidad especialidad,
        Consultorio consultorio
) {
    public record MedicoRef(
            Long id,
            String nombre,
            String apellido
    ) {
    }
}
