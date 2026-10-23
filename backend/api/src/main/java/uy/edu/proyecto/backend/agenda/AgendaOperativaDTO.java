package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.OffsetDateTime;

public record AgendaOperativaDTO(
        Long consultaId,
        Socio socio,
        Medico medico,
        Especialidad especialidad,
        LocalDate fecha,
        String horaInicio,
        String horaFin,
        Consultorio consultorio,
        String estado,
        OffsetDateTime llegadaEn
) {
    public record Socio(String ci, String nombre, String apellido) {
    }

    public record Medico(Long id, String nombre, String apellido) {
    }

    public record Especialidad(Long id, String nombre, boolean requierePase) {
    }

    public record Consultorio(Long id, String nombre, String ubicacion) {
    }
}
