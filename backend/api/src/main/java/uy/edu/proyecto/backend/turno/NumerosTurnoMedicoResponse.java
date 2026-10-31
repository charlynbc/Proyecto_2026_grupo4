package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

public record NumerosTurnoMedicoResponse(
        Turno turno,
        List<NumeroItem> items
) {
    public record Turno(
            Long id,
            LocalDate fecha,
            Especialidad especialidad,
            Consultorio consultorio,
            String estado
    ) {
    }

    public record NumeroItem(
            Long numeroId,
            int numero,
            String horaInicio,
            String horaFin,
            Consulta consulta,
            boolean disponible
    ) {
    }

    public record Consulta(
            Long id,
            String estado,
            Paciente paciente,
            OffsetDateTime llegadaEn
    ) {
    }

    public record Paciente(
            Long id,
            String ci,
            String nombre,
            String apellido
    ) {
    }
}
