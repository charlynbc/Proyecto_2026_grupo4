-- Horarios futuros disponibles de un profesional.

SELECT
    h.id,
    h.profesional_id,
    h.inicio,
    h.fin

FROM "POC".horario h

WHERE h.profesional_id = ?

AND h.inicio >= ?

AND h.inicio < ?

AND h.inicio > CURRENT_TIMESTAMP

AND NOT EXISTS (

    SELECT 1

    FROM "POC".reserva r

    WHERE r.horario_id = h.id

    AND r.estado = 'ACTIVA'

)

ORDER BY
    h.inicio,
    h.id;
