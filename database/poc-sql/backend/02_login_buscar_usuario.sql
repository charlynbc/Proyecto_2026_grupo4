-- Búsqueda para login.
-- Parámetro: cédula.

SELECT
    id,
    nombre,
    cedula,
    password_hash
FROM "POC".usuario
WHERE cedula = ?;
