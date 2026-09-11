package uy.edu.proyecto.pocbackend.horario;

import java.time.OffsetDateTime;

/**
 * DTO de horario, mismas columnas que 08_horarios_disponibles.sql
 * (id, profesional_id, inicio, fin).
 */
public record Horario(Long id, Long profesionalId, OffsetDateTime inicio, OffsetDateTime fin) {
}
