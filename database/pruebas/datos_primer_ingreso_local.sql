-- Cuentas FICTICIAS pendientes de primer ingreso para probar RF-02 con Mailpit.
--
-- Uso exclusivo en una base local descartable (p. ej. PostgreSQL 17 en Docker).
-- No hace TRUNCATE ni DELETE: solo inserta y es repetible (ON CONFLICT).
-- Los correos terminan en @mailpit.local: Mailpit los recibe todos y no los
-- reenvia a nadie. NO ejecutar contra Supabase/Railway.
--
--   docker exec -i <contenedor-postgres> psql -U postgres -d <base> -v ON_ERROR_STOP=1 \
--       < database/pruebas/datos_primer_ingreso_local.sql
--
-- CI (todas con digito verificador valido):
--   40000018  SOCIO     pendiente   -> acceso SOCIO
--   40000024  MEDICO    pendiente   -> acceso EMPLEADO
--   40000030  SOCIO     inactivada  -> no recibe enlace (cuenta inhabilitada)

INSERT INTO public.persona (ci, nombre, apellido, fecha_nacimiento) VALUES
    ('40000018', 'Paula',  'Prueba Socia',  DATE '1990-03-10'),
    ('40000024', 'Mateo',  'Prueba Medico', DATE '1982-07-21'),
    ('40000030', 'Irene',  'Prueba Inactiva', DATE '1975-11-02')
ON CONFLICT (ci) DO NOTHING;

INSERT INTO public.cuenta (ci, rol, correo, telefono_1, primer_ingreso_completado, habilitada)
SELECT v.ci, v.rol, v.correo, '099000000', FALSE, v.habilitada
FROM (VALUES
    ('40000018', 'SOCIO',  'paula.socia@mailpit.local',   TRUE),
    ('40000024', 'MEDICO', 'mateo.medico@mailpit.local',  TRUE),
    ('40000030', 'SOCIO',  'irene.inactiva@mailpit.local', FALSE)
) AS v(ci, rol, correo, habilitada)
WHERE NOT EXISTS (SELECT 1 FROM public.cuenta c WHERE c.ci = v.ci AND c.rol = v.rol);
