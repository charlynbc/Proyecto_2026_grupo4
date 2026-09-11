package uy.edu.proyecto.pocbackend.reserva;

/**
 * Cuerpo esperado de PATCH /reservas/{id}/cancelacion.
 * Coincide con los parametros de database/poc-sql/backend/10_reserva_cancelar.sql.
 */
public record CancelacionRequest(Long usuarioId) {
}
