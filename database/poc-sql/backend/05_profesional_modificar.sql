-- Modificar profesional.

UPDATE "POC".profesional
SET nombre = ?
WHERE id = ?
RETURNING id, nombre;
