-- Cancelar una reserva.

UPDATE "POC".reserva

SET
    estado = 'CANCELADA',
    fecha_cancelacion = CURRENT_TIMESTAMP

WHERE id = ?

AND usuario_id = ?

AND estado = 'ACTIVA'

RETURNING
    id,
    usuario_id,
    horario_id,
    estado,
    fecha_cancelacion;
