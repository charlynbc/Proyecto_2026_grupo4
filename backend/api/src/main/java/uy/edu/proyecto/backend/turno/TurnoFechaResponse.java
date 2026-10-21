package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

public record TurnoFechaResponse(
        Long id,
        Long turnoSemanalId,
        LocalDate fecha,
        int diaSemana,
        String horaInicio,
        String horaFin,
        MedicoRef medico,
        Especialidad especialidad,
        Consultorio consultorio,
        long cantidadNumeros,
        String estado
) {
    public record MedicoRef(Long id, String nombre, String apellido) {
    }
}
