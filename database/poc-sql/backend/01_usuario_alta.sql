-- Alta de usuario.
-- Parámetros:
-- 1 nombre
-- 2 cédula sin separadores
-- 3 hash BCrypt de la clave.

INSERT INTO "POC".usuario (
    nombre,
    cedula,
    password_hash
)
VALUES (?, ?, ?)
RETURNING id, nombre, cedula;
