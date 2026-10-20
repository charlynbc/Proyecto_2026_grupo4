-- Prueba de humo del esquema: carga datos mínimos y comprueba que la base
-- rechaza lo que el Modelo de Datos prohíbe. Se ejecuta después de schema.sql,
-- en la integración continua, y no deja datos: todo termina en ROLLBACK.
--
-- Cada bloque "debe fallar" intenta una operación inválida. Si la base la
-- acepta, el bloque lanza un error y el script se detiene (ON_ERROR_STOP).
-- Los datos base se cargan con id explícitos (OVERRIDING SYSTEM VALUE) para
-- que el script funcione aunque las secuencias ya hayan avanzado; las
-- consultas se identifican por sus datos, porque un INSERT que falla igual
-- consume un valor de la secuencia.

\set ON_ERROR_STOP on
BEGIN;

INSERT INTO persona (ci, nombre, apellido, fecha_nacimiento) VALUES
    ('12345672', 'Ana',   'Pérez',  '1990-05-10'),
    ('23456783', 'Bruno', 'Gómez',  '1985-02-01'),
    ('34567894', 'Carla', 'Suárez', '1979-11-20');

INSERT INTO cuenta (id_cuenta, ci, rol, correo, telefono_1) OVERRIDING SYSTEM VALUE VALUES
    (1, '12345672', 'SOCIO',       'ana@example.com',   '099000001'),  -- 1
    (2, '23456783', 'MEDICO',      'bruno@example.com', '099000002'),  -- 2
    (3, '34567894', 'FUNCIONARIO', 'carla@example.com', '099000003'),  -- 3
    (4, '34567894', 'SOCIO',       'carla@example.com', '099000003');  -- 4: socio y empleado a la vez

INSERT INTO especialidad (id_especialidad, nombre, requiere_pase) OVERRIDING SYSTEM VALUE
    VALUES (1, 'Cardiología', true), (2, 'Medicina general', false);
INSERT INTO medico_especialidad VALUES (2, 2);
INSERT INTO consultorio (id_consultorio, nombre, ubicacion) OVERRIDING SYSTEM VALUE
    VALUES (1, '101', 'Planta baja');
INSERT INTO turno_semanal (id_turno_semanal, id_medico, id_especialidad, id_consultorio,
                           id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)
    OVERRIDING SYSTEM VALUE VALUES (1, 2, 2, 1, 3, 1, '2026-11-02', '2026-12-28');
INSERT INTO numero_semanal (id_numero_semanal, id_turno_semanal, numero, hora_inicio, hora_fin)
    OVERRIDING SYSTEM VALUE VALUES (1, 1, 1, '09:00', '09:15'), (2, 1, 2, '09:15', '09:30');
INSERT INTO turno (id_turno, id_turno_semanal, id_consultorio, fecha) OVERRIDING SYSTEM VALUE
    VALUES (1, 1, 1, '2026-11-02');
INSERT INTO numero (id_numero, id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)
    OVERRIDING SYSTEM VALUE VALUES (1, 1, 1, 1, '09:00', '09:15'), (2, 1, 2, 2, '09:15', '09:30');

-- RNF-13 / R-MDAT-10: un número no admite dos consultas no canceladas.
INSERT INTO consulta (id_socio, id_numero) VALUES (1, 1);
DO $$ BEGIN
    INSERT INTO consulta (id_socio, id_numero) VALUES (4, 1);
    RAISE EXCEPTION 'FALLA: se aceptaron dos consultas activas para el mismo número';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: número único (RNF-13)';
END $$;

-- Una cancelación libera el número para otra agenda.
UPDATE consulta SET estado = 'CANCELADA_SOCIO', cancelada_por = 1, cancelada_en = now()
    WHERE id_numero = 1 AND id_socio = 1;
INSERT INTO consulta (id_socio, id_numero) VALUES (4, 1);

-- R-MDAT-14: una cancelación sin responsable se rechaza.
DO $$ BEGIN
    UPDATE consulta SET estado = 'CANCELADA_SOCIO'
        WHERE id_numero = 1 AND estado = 'AGENDADA';
    RAISE EXCEPTION 'FALLA: se aceptó una cancelación sin responsable';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'ok: cancelación con responsable (R-MDAT-14)';
END $$;

-- R-MDAT-02: una sola cuenta SOCIO por CI.
DO $$ BEGIN
    INSERT INTO cuenta (id_cuenta, ci, rol, correo, telefono_1) OVERRIDING SYSTEM VALUE
        VALUES (98, '12345672', 'SOCIO', 'x@example.com', '1');
    RAISE EXCEPTION 'FALLA: se aceptaron dos cuentas SOCIO para la misma CI';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: una cuenta socio por CI (R-MDAT-02)';
END $$;

-- R-MDAT-02: una sola cuenta de empleado habilitada por CI.
DO $$ BEGIN
    INSERT INTO cuenta (id_cuenta, ci, rol, correo, telefono_1) OVERRIDING SYSTEM VALUE
        VALUES (99, '34567894', 'MEDICO', 'x@example.com', '1');
    RAISE EXCEPTION 'FALLA: se aceptaron dos cuentas de empleado habilitadas para la misma CI';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: un empleado habilitado por CI (R-MDAT-02)';
END $$;

-- El rol de una cuenta es inmutable.
DO $$ BEGIN
    UPDATE cuenta SET rol = 'ADMINISTRADOR' WHERE id_cuenta = 3;
    RAISE EXCEPTION 'FALLA: se aceptó un cambio de rol';
EXCEPTION WHEN raise_exception THEN
    IF SQLERRM LIKE 'FALLA%' THEN RAISE; END IF;
    RAISE NOTICE 'ok: rol inmutable';
END $$;

-- R-MDAT-03: no se completa el primer ingreso sin dirección ni contraseña.
DO $$ BEGIN
    UPDATE cuenta SET primer_ingreso_completado = true WHERE id_cuenta = 1;
    RAISE EXCEPTION 'FALLA: se completó el primer ingreso sin dirección ni contraseña';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'ok: primer ingreso completo (R-MDAT-03)';
END $$;

-- R-MDAT-04: el nombre de la especialidad no distingue mayúsculas.
DO $$ BEGIN
    INSERT INTO especialidad (id_especialidad, nombre, requiere_pase) OVERRIDING SYSTEM VALUE
        VALUES (99, 'CARDIOLOGÍA', true);
    RAISE EXCEPTION 'FALLA: se aceptó una especialidad repetida con otras mayúsculas';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: especialidad única (R-MDAT-04)';
END $$;

-- El turno semanal exige que el médico tenga esa especialidad.
DO $$ BEGIN
    INSERT INTO turno_semanal (id_turno_semanal, id_medico, id_especialidad, id_consultorio,
                               id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)
        OVERRIDING SYSTEM VALUE VALUES (99, 2, 1, 1, 3, 2, '2026-11-03', '2026-12-29');
    RAISE EXCEPTION 'FALLA: se aceptó un turno de una especialidad que el médico no tiene';
EXCEPTION WHEN foreign_key_violation THEN RAISE NOTICE 'ok: médico con la especialidad del turno';
END $$;

-- R-MDAT-07: los extremos de una franja están en múltiplos de cinco minutos.
DO $$ BEGIN
    INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)
        VALUES (1, 3, '09:30', '09:42');
    RAISE EXCEPTION 'FALLA: se aceptó una franja que no es múltiplo de cinco minutos';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'ok: franjas en múltiplos de 5 minutos (R-MDAT-07)';
END $$;

-- Atención, pase y uso del pase (R-MDAT-10 y R-MDAT-16).
INSERT INTO atencion (id_atencion, id_consulta, id_medico, afeccion) OVERRIDING SYSTEM VALUE
    VALUES (1, (SELECT id_consulta FROM consulta WHERE id_numero = 1 AND estado = 'AGENDADA'), 2, 'Control');
UPDATE consulta SET estado = 'ATENDIDA', resultado_registrado_por = 2, fecha_resultado = now()
    WHERE id_numero = 1 AND estado = 'AGENDADA';
INSERT INTO pase (id_pase, id_atencion, id_especialidad_destino, vence_el) OVERRIDING SYSTEM VALUE
    VALUES (1, 1, 1, '2027-01-31');
INSERT INTO consulta (id_socio, id_numero, id_pase) VALUES (4, 2, 1);

DO $$ BEGIN
    INSERT INTO atencion (id_atencion, id_consulta, id_medico, afeccion) OVERRIDING SYSTEM VALUE
        VALUES (99, (SELECT id_consulta FROM consulta WHERE estado = 'ATENDIDA'), 2, 'Otra');
    RAISE EXCEPTION 'FALLA: se aceptaron dos atenciones para la misma consulta';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: una atención por consulta (R-MDAT-16)';
END $$;

DO $$ BEGIN
    UPDATE consulta SET id_pase = 1 WHERE estado = 'CANCELADA_SOCIO';  -- cancelada: no cuenta
    INSERT INTO numero (id_numero, id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)
        OVERRIDING SYSTEM VALUE VALUES (3, 1, 1, 3, '09:30', '09:45');
    INSERT INTO consulta (id_socio, id_numero, id_pase) VALUES (4, 3, 1);
    RAISE EXCEPTION 'FALLA: se usó el mismo pase en dos consultas activas';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: pase de uso único (R-MDAT-10)';
END $$;

-- R-MDAT-21: un solo recordatorio por consulta.
INSERT INTO notificacion (id_consulta, tipo, contenido) VALUES ((SELECT id_consulta FROM consulta WHERE id_pase = 1 AND estado = 'AGENDADA'), 'RECORDATORIO', 'Mañana tenés consulta');
DO $$ BEGIN
    INSERT INTO notificacion (id_consulta, tipo, contenido) VALUES ((SELECT id_consulta FROM consulta WHERE id_pase = 1 AND estado = 'AGENDADA'), 'RECORDATORIO', 'Otra vez');
    RAISE EXCEPTION 'FALLA: se aceptaron dos recordatorios para la misma consulta';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: un recordatorio por consulta (R-MDAT-21)';
END $$;

-- R-MDAT-20: un envío por correo exige dirección y no dispositivo.
DO $$ BEGIN
    INSERT INTO envio_notificacion (id_notificacion, canal) VALUES ((SELECT min(id_notificacion) FROM notificacion), 'CORREO');
    RAISE EXCEPTION 'FALLA: se aceptó un envío por correo sin dirección';
EXCEPTION WHEN check_violation THEN RAISE NOTICE 'ok: destino del envío según canal (R-MDAT-20)';
END $$;

-- R-MDAT-12: un aviso de llegada por socio y día.
INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (4, 3, '2026-11-02');
DO $$ BEGIN
    INSERT INTO aviso_llegada (id_socio, id_funcionario, fecha) VALUES (4, 3, '2026-11-02');
    RAISE EXCEPTION 'FALLA: se aceptaron dos avisos de llegada el mismo día';
EXCEPTION WHEN unique_violation THEN RAISE NOTICE 'ok: un aviso por socio y día (R-MDAT-12)';
END $$;

-- R-MDAT-01: corregir una CI se propaga a sus cuentas.
UPDATE persona SET ci = '12345680' WHERE ci = '12345672';
DO $$ BEGIN
    IF (SELECT ci FROM cuenta WHERE id_cuenta = 1) <> '12345680' THEN
        RAISE EXCEPTION 'FALLA: la corrección de CI no se propagó a la cuenta';
    END IF;
    RAISE NOTICE 'ok: corrección de CI propagada (R-MDAT-01)';
END $$;

ROLLBACK;
\echo 'Esquema verificado: todas las restricciones probadas se cumplen.'
