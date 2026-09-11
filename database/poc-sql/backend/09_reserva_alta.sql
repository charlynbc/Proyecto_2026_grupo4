-- Alta de reserva.
-- Parámetros:
-- usuario_id
-- horario_id

INSERT INTO "POC".reserva (
    usuario_id,
    horario_id
)

SELECT
    ?,
    h.id

FROM "POC".horario h

WHERE h.id = ?

AND h.inicio > CURRENT_TIMESTAMP

RETURNING
    id,
    usuario_id,
    horario_id,
    estado,
    fecha_creacion;
