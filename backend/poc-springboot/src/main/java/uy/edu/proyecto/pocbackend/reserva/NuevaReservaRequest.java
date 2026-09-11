package uy.edu.proyecto.pocbackend.reserva;

/**
 * Cuerpo esperado de POST /reservas.
 * Coincide con los parametros de database/poc-sql/backend/09_reserva_alta.sql.
 */
public record NuevaReservaRequest(Long usuarioId, Long horarioId) {
}
