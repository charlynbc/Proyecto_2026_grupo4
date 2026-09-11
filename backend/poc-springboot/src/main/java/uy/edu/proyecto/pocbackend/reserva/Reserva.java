package uy.edu.proyecto.pocbackend.reserva;

import java.time.OffsetDateTime;

/**
 * DTO de reserva, mismas columnas de referencia que
 * database/poc-sql/backend/09_reserva_alta.sql (id, usuario_id, horario_id, estado, fecha_creacion).
 */
public record Reserva(Long id, Long usuarioId, Long horarioId, String estado, OffsetDateTime fechaCreacion) {
}
