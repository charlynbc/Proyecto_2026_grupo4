
-- USUARIOS
SELECT
    id,
    nombre,
    cedula
FROM "POC".usuario
ORDER BY nombre;


-- PROFESIONALES
SELECT
    id,
    nombre
FROM "POC".profesional
ORDER BY nombre;


-- CANTIDAD DE HORARIOS LIBRES Y OCUPADOS
SELECT

    COUNT(*) AS horarios,

    COUNT(*) FILTER (
        WHERE r.id IS NULL
    ) AS libres,

    COUNT(*) FILTER (
        WHERE r.id IS NOT NULL
    ) AS ocupados

FROM "POC".horario h

JOIN "POC".profesional p
    ON p.id = h.profesional_id

LEFT JOIN "POC".reserva r
    ON r.horario_id = h.id
    AND r.estado = 'ACTIVA';


-- AGENDA COMPLETA
SELECT

    h.id AS horario_id,

    p.nombre AS profesional,

    h.inicio AT TIME ZONE 'America/Montevideo'
        AS inicio,

    h.fin AT TIME ZONE 'America/Montevideo'
        AS fin,

    CASE
        WHEN r.id IS NULL
        THEN 'DISPONIBLE'
        ELSE 'RESERVADO'
    END AS estado,

    u.nombre AS usuario,

    r.id AS reserva_id

FROM "POC".horario h

JOIN "POC".profesional p
    ON p.id = h.profesional_id

LEFT JOIN "POC".reserva r
    ON r.horario_id = h.id
    AND r.estado = 'ACTIVA'

LEFT JOIN "POC".usuario u
    ON u.id = r.usuario_id

ORDER BY
    h.inicio,
    p.nombre;


-- HISTORIAL DE RESERVAS
SELECT

    r.id AS reserva_id,

    u.nombre AS usuario,

    h.id AS horario_id,

    p.nombre AS profesional,

    h.inicio AT TIME ZONE 'America/Montevideo'
        AS inicio,

    r.estado,

    r.fecha_creacion AT TIME ZONE 'America/Montevideo'
        AS fecha_creacion,

    r.fecha_cancelacion AT TIME ZONE 'America/Montevideo'
        AS fecha_cancelacion

FROM "POC".reserva r

JOIN "POC".usuario u
    ON u.id = r.usuario_id

JOIN "POC".horario h
    ON h.id = r.horario_id

JOIN "POC".profesional p
    ON p.id = h.profesional_id

ORDER BY
    h.inicio,
    p.nombre,
    r.fecha_creacion,
    r.id;

