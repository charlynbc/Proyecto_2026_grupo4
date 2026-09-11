-- Alta de profesional.

INSERT INTO "POC".profesional (nombre)
VALUES (?)
RETURNING id, nombre;
