-- Baja de profesional.

DELETE FROM "POC".profesional
WHERE id = ?
RETURNING id, nombre;
