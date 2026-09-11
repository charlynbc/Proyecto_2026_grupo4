-- Historial de reservas de un usuario.

SELECT

    r.id,
    r.estado,
    r.fecha_creacion,
    r.fecha_cancelacion,

    h.id AS horario_id,
    h.inicio,
    h.fin,

    p.id AS profesional_id,
    p.nombre AS profesional

FROM "POC".reserva r

JOIN "POC".horario h
    ON h.id = r.horario_id

JOIN "POC".profesional p
    ON p.id = h.profesional_id

WHERE r.usuario_id = ?

ORDER BY
    h.inicio DESC,
    r.id DESC;
