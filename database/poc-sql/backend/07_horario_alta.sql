-- Alta de horario.
-- Parámetros:
-- profesional_id
-- inicio
-- fin

INSERT INTO "POC".horario (
    profesional_id,
    inicio,
    fin
)
VALUES (?, ?, ?)

RETURNING
    id,
    profesional_id,
    inicio,
    fin;
