-- Ejecutar inmediatamente tras confirmar la carga y antes de operar la demo.
BEGIN READ ONLY;
SET LOCAL search_path = pg_catalog, public;
SET LOCAL TIME ZONE 'America/Montevideo';
DO $destino$ BEGIN
 IF current_database() <> 'test' THEN RAISE EXCEPTION 'Destino incorrecto: %', current_database(); END IF;
END $destino$;
SELECT set_config('demo.desplazamiento', (max(fecha)-35-DATE '2026-10-27')::text, true) FROM public.turno;
-- 1. Cantidad de persona: 50
DO $v$ BEGIN
 IF (SELECT count(*) <> 50 AS error FROM public.persona) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de persona: 50'; END IF;
END $v$;

-- 2. Cantidad de cuenta: 50
DO $v$ BEGIN
 IF (SELECT count(*) <> 50 AS error FROM public.cuenta) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de cuenta: 50'; END IF;
END $v$;

-- 3. Cantidad de especialidad: 6
DO $v$ BEGIN
 IF (SELECT count(*) <> 6 AS error FROM public.especialidad) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de especialidad: 6'; END IF;
END $v$;

-- 4. Cantidad de medico_especialidad: 8
DO $v$ BEGIN
 IF (SELECT count(*) <> 8 AS error FROM public.medico_especialidad) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de medico_especialidad: 8'; END IF;
END $v$;

-- 5. Cantidad de sesion: 0
DO $v$ BEGIN
 IF (SELECT count(*) <> 0 AS error FROM public.sesion) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de sesion: 0'; END IF;
END $v$;

-- 6. Cantidad de enlace_cuenta: 0
DO $v$ BEGIN
 IF (SELECT count(*) <> 0 AS error FROM public.enlace_cuenta) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de enlace_cuenta: 2'; END IF;
END $v$;

-- 7. Cantidad de consultorio: 6
DO $v$ BEGIN
 IF (SELECT count(*) <> 6 AS error FROM public.consultorio) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de consultorio: 6'; END IF;
END $v$;

-- 8. Cantidad de turno_semanal: 24
DO $v$ BEGIN
 IF (SELECT count(*) <> 24 AS error FROM public.turno_semanal) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de turno_semanal: 24'; END IF;
END $v$;

-- 9. Cantidad de numero_semanal: 192
DO $v$ BEGIN
 IF (SELECT count(*) <> 192 AS error FROM public.numero_semanal) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de numero_semanal: 192'; END IF;
END $v$;

-- 10. Cantidad de turno: 312
DO $v$ BEGIN
 IF (SELECT count(*) <> 312 AS error FROM public.turno) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de turno: 312'; END IF;
END $v$;

-- 11. Cantidad de numero: 2496
DO $v$ BEGIN
 IF (SELECT count(*) <> 2496 AS error FROM public.numero) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de numero: 2496'; END IF;
END $v$;

-- 12. Cantidad de aviso_llegada: 178
DO $v$ BEGIN
 IF (SELECT count(*) <> 178 AS error FROM public.aviso_llegada) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de aviso_llegada: 178'; END IF;
END $v$;

-- 13. Cantidad de turno_evento: 0
DO $v$ BEGIN
 IF (SELECT count(*) <> 0 AS error FROM public.turno_evento) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de turno_evento: 0'; END IF;
END $v$;

-- 14. Cantidad de consulta: 267
DO $v$ BEGIN
 IF (SELECT count(*) <> 267 AS error FROM public.consulta) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de consulta: 267'; END IF;
END $v$;

-- 15. Cantidad de atencion: 170
DO $v$ BEGIN
 IF (SELECT count(*) <> 170 AS error FROM public.atencion) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de atencion: 170'; END IF;
END $v$;

-- 16. Cantidad de pase: 91
DO $v$ BEGIN
 IF (SELECT count(*) <> 91 AS error FROM public.pase) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de pase: 91'; END IF;
END $v$;

-- 19. Cantidad de notificacion: 526
DO $v$ BEGIN
 IF (SELECT count(*) <> 526 AS error FROM public.notificacion) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de notificacion: 526'; END IF;
END $v$;

-- 20. Cantidad de dispositivo_push: 0
DO $v$ BEGIN
 IF (SELECT count(*) <> 0 AS error FROM public.dispositivo_push) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de dispositivo_push: 0'; END IF;
END $v$;

-- 21. Cantidad de envio_notificacion: 0
DO $v$ BEGIN
 IF (SELECT count(*) <> 0 AS error FROM public.envio_notificacion) THEN RAISE EXCEPTION 'Verificación fallida: Cantidad de envio_notificacion: 0'; END IF;
END $v$;

-- 22. Distribución de roles
DO $v$ BEGIN
 IF (SELECT EXISTS (SELECT 1 FROM (VALUES ('SOCIO',36),('MEDICO',8),('FUNCIONARIO',4),('ADMINISTRADOR',2)) v(rol,cantidad) WHERE (SELECT count(*) FROM public.cuenta c WHERE c.rol=v.rol)<>v.cantidad) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Distribución de roles'; END IF;
END $v$;

-- 23. Cuatro especialidades con pase y dos sin pase
DO $v$ BEGIN
 IF (SELECT count(*) FILTER(WHERE requiere_pase)<>4 OR count(*) FILTER(WHERE NOT requiere_pase)<>2 AS error FROM public.especialidad) THEN RAISE EXCEPTION 'Verificación fallida: Cuatro especialidades con pase y dos sin pase'; END IF;
END $v$;

-- 24. Roles y especialidad de cada turno
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.turno_semanal t JOIN public.cuenta m ON m.id_cuenta=t.id_medico JOIN public.cuenta f ON f.id_cuenta=t.id_funcionario_alta WHERE m.rol<>'MEDICO' OR f.rol<>'FUNCIONARIO' OR NOT EXISTS(SELECT 1 FROM public.medico_especialidad me WHERE me.id_medico=t.id_medico AND me.id_especialidad=t.id_especialidad)) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Roles y especialidad de cada turno'; END IF;
END $v$;

-- 25. Fechas dentro del patrón y día correcto
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.turno t JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE t.fecha NOT BETWEEN ts.fecha_inicio AND ts.fecha_fin OR extract(isodow FROM t.fecha)<>ts.dia_semana OR t.id_consultorio<>ts.id_consultorio) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Fechas dentro del patrón y día correcto'; END IF;
END $v$;

-- 26. Patrones completos por fecha
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.turno_semanal ts CROSS JOIN LATERAL generate_series(ts.fecha_inicio,ts.fecha_fin,interval '1 day') d WHERE extract(isodow FROM d)=ts.dia_semana AND NOT EXISTS(SELECT 1 FROM public.turno t WHERE t.id_turno_semanal=ts.id_turno_semanal AND t.fecha=d::date)) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Patrones completos por fecha'; END IF;
END $v$;

-- 27. Números corresponden al patrón
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.numero n JOIN public.turno t USING(id_turno) JOIN public.numero_semanal ns USING(id_numero_semanal) WHERE ns.id_turno_semanal<>t.id_turno_semanal OR (n.numero,n.hora_inicio,n.hora_fin) IS DISTINCT FROM (ns.numero,ns.hora_inicio,ns.hora_fin)) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Números corresponden al patrón'; END IF;
END $v$;

-- 28. Ocho números en cada turno
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.turno t LEFT JOIN public.numero n USING(id_turno) GROUP BY t.id_turno HAVING count(n.id_numero)<>8) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Ocho números en cada turno'; END IF;
END $v$;

-- 29. Médicos y consultorios sin solapamientos
DO $v$ BEGIN
 IF (WITH s AS (SELECT n.*,t.fecha,t.id_consultorio,ts.id_medico FROM public.numero n JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal)) SELECT EXISTS(SELECT 1 FROM s a JOIN s b ON a.id_numero<b.id_numero AND a.fecha=b.fecha AND (a.id_medico=b.id_medico OR a.id_consultorio=b.id_consultorio) AND a.hora_inicio<b.hora_fin AND b.hora_inicio<a.hora_fin) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Médicos y consultorios sin solapamientos'; END IF;
END $v$;

-- 30. Socios sin consultas superpuestas
DO $v$ BEGIN
 IF (WITH s AS (SELECT c.id_consulta,c.id_socio,t.fecha,n.hora_inicio,n.hora_fin FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE c.estado NOT LIKE 'CANCELADA%') SELECT EXISTS(SELECT 1 FROM s a JOIN s b ON a.id_consulta<b.id_consulta AND a.id_socio=b.id_socio AND a.fecha=b.fecha AND a.hora_inicio<b.hora_fin AND b.hora_inicio<a.hora_fin) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Socios sin consultas superpuestas'; END IF;
END $v$;

-- 31. Máximo de tres reservas por socio
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta WHERE estado='AGENDADA' GROUP BY id_socio HAVING count(*)>3) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Máximo de tres reservas por socio'; END IF;
END $v$;

-- 32. Una reserva por especialidad
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE c.estado='AGENDADA' GROUP BY c.id_socio,ts.id_especialidad HAVING count(*)>1) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Una reserva por especialidad'; END IF;
END $v$;

-- 33. Reservas históricas sin duplicar especialidad simultánea
DO $v$ BEGIN
 IF (WITH s AS (SELECT c.id_consulta,c.id_socio,ts.id_especialidad,c.agendada_en,coalesce(c.cancelada_en,c.fecha_resultado,'infinity'::timestamptz) cierre FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal)) SELECT EXISTS(SELECT 1 FROM s a JOIN s b ON a.id_consulta<b.id_consulta AND a.id_socio=b.id_socio AND a.id_especialidad=b.id_especialidad AND a.agendada_en<b.cierre AND b.agendada_en<a.cierre) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Reservas históricas sin duplicar especialidad simultánea'; END IF;
END $v$;

-- 34. Máximo de tres reservas también al agendar cada consulta
DO $v$ BEGIN
 IF (WITH s AS (SELECT c.id_consulta,c.id_socio,c.agendada_en,coalesce(c.cancelada_en,c.fecha_resultado,'infinity'::timestamptz) cierre FROM public.consulta c) SELECT EXISTS(SELECT 1 FROM s a JOIN s b ON a.id_socio=b.id_socio AND b.agendada_en<=a.agendada_en AND b.cierre>a.agendada_en GROUP BY a.id_consulta HAVING count(*)>3) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Máximo de tres reservas también al agendar cada consulta'; END IF;
END $v$;

-- 35. Consultas de cuentas socio activadas
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.cuenta u ON u.id_cuenta=c.id_socio WHERE u.rol<>'SOCIO' OR NOT u.habilitada OR NOT u.primer_ingreso_completado) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Consultas de cuentas socio activadas'; END IF;
END $v$;

-- 36. Pases obligatorios y ausentes en acceso directo
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) JOIN public.especialidad e USING(id_especialidad) WHERE e.requiere_pase<>(c.id_pase IS NOT NULL)) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Pases obligatorios y ausentes en acceso directo'; END IF;
END $v$;

-- 37. Pases propios, especialidad correcta y fechas coherentes
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) JOIN public.pase p USING(id_pase) JOIN public.atencion a ON a.id_atencion=p.id_atencion JOIN public.consulta origen ON origen.id_consulta=a.id_consulta WHERE origen.id_socio<>c.id_socio OR p.id_especialidad_destino<>ts.id_especialidad OR p.vence_el<t.fecha OR p.emitido_en>c.agendada_en OR p.emitido_en<a.registrada_en) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Pases propios, especialidad correcta y fechas coherentes'; END IF;
END $v$;

-- 38. Pases sin duplicados para socio y especialidad
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.pase p JOIN public.atencion a USING(id_atencion) JOIN public.consulta c USING(id_consulta) GROUP BY c.id_socio,p.id_especialidad_destino HAVING count(*)>1) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Pases sin duplicados para socio y especialidad'; END IF;
END $v$;

-- 42. Toda consulta atendida tiene una atención del médico correcto
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) LEFT JOIN public.atencion a USING(id_consulta) WHERE (c.estado='ATENDIDA')<>(a.id_atencion IS NOT NULL) OR (a.id_atencion IS NOT NULL AND (a.id_medico<>ts.id_medico OR a.registrada_en<>c.fecha_resultado))) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Toda consulta atendida tiene una atención del médico correcto'; END IF;
END $v$;

-- 43. Resultado registrado por el médico del turno
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE c.resultado_registrado_por IS NOT NULL AND c.resultado_registrado_por<>ts.id_medico) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Resultado registrado por el médico del turno'; END IF;
END $v$;

-- 44. Llegada previa a los resultados
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE c.fecha_resultado IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.aviso_llegada a WHERE a.id_socio=c.id_socio AND a.fecha=t.fecha AND a.registrada_en<=c.fecha_resultado)) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Llegada previa a los resultados'; END IF;
END $v$;

-- 45. Llegadas con roles y fechas correctos
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.aviso_llegada a JOIN public.cuenta s ON s.id_cuenta=a.id_socio JOIN public.cuenta f ON f.id_cuenta=a.id_funcionario WHERE s.rol<>'SOCIO' OR f.rol<>'FUNCIONARIO' OR (a.registrada_en AT TIME ZONE 'America/Montevideo')::date<>a.fecha) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Llegadas con roles y fechas correctos'; END IF;
END $v$;

-- 46. Reservas creadas a más tardar al comenzar el día 27
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta WHERE agendada_en>(TIMESTAMPTZ '2026-10-27T00:00:00-03:00' + make_interval(days => current_setting('demo.desplazamiento')::int))) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Reservas creadas a más tardar al comenzar el día 27'; END IF;
END $v$;

-- 47. Anticipación de dos horas a treinta días al reservar
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE ((t.fecha+n.hora_inicio) AT TIME ZONE 'America/Montevideo')-c.agendada_en NOT BETWEEN interval '2 hours' AND interval '30 days') AS error) THEN RAISE EXCEPTION 'Verificación fallida: Anticipación de dos horas a treinta días al reservar'; END IF;
END $v$;

-- 48. 48 cuentas listas y dos pendientes
DO $v$ BEGIN
 IF (SELECT count(*) FILTER(WHERE primer_ingreso_completado)<>48 OR count(*) FILTER(WHERE NOT primer_ingreso_completado)<>2 AS error FROM public.cuenta) THEN RAISE EXCEPTION 'Verificación fallida: 48 cuentas listas y dos pendientes'; END IF;
END $v$;

-- 49. Hashes BCrypt en cuentas activas
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.cuenta WHERE primer_ingreso_completado AND (contrasena_hash NOT LIKE '$2%$12$%' OR length(contrasena_hash)<>60)) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Hashes BCrypt en cuentas activas'; END IF;
END $v$;

-- 51. Cuentas creadas antes de reservar
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.cuenta u ON u.id_cuenta=c.id_socio WHERE u.fecha_alta>c.agendada_en) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Cuentas creadas antes de reservar'; END IF;
END $v$;

-- 52. Doce consultas pendientes el D+0
DO $v$ BEGIN
 IF (SELECT count(*)<>12 AS error FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE t.fecha=(DATE '2026-10-27' + current_setting('demo.desplazamiento')::int) AND c.estado='AGENDADA') THEN RAISE EXCEPTION 'Verificación fallida: Doce consultas pendientes el 2026-10-27'; END IF;
END $v$;

-- 53. Doce consultas pendientes el D+1
DO $v$ BEGIN
 IF (SELECT count(*)<>12 AS error FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE t.fecha=(DATE '2026-10-28' + current_setting('demo.desplazamiento')::int) AND c.estado='AGENDADA') THEN RAISE EXCEPTION 'Verificación fallida: Doce consultas pendientes el 2026-10-28'; END IF;
END $v$;

-- 54. Doce consultas pendientes el D+2
DO $v$ BEGIN
 IF (SELECT count(*)<>12 AS error FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE t.fecha=(DATE '2026-10-29' + current_setting('demo.desplazamiento')::int) AND c.estado='AGENDADA') THEN RAISE EXCEPTION 'Verificación fallida: Doce consultas pendientes el 2026-10-29'; END IF;
END $v$;

-- 55. Doce consultas pendientes el D+3
DO $v$ BEGIN
 IF (SELECT count(*)<>12 AS error FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE t.fecha=(DATE '2026-10-30' + current_setting('demo.desplazamiento')::int) AND c.estado='AGENDADA') THEN RAISE EXCEPTION 'Verificación fallida: Doce consultas pendientes el 2026-10-30'; END IF;
END $v$;

-- 56. Doce consultas pendientes el D+4
DO $v$ BEGIN
 IF (SELECT count(*)<>12 AS error FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE t.fecha=(DATE '2026-10-31' + current_setting('demo.desplazamiento')::int) AND c.estado='AGENDADA') THEN RAISE EXCEPTION 'Verificación fallida: Doce consultas pendientes el 2026-10-31'; END IF;
END $v$;

-- 57. Veinte reservas entre D+7 y D+25
DO $v$ BEGIN
 IF (SELECT count(*)<>20 AS error FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE c.estado='AGENDADA' AND t.fecha BETWEEN (DATE '2026-11-03' + current_setting('demo.desplazamiento')::int) AND (DATE '2026-11-21' + current_setting('demo.desplazamiento')::int)) THEN RAISE EXCEPTION 'Verificación fallida: Veinte reservas de noviembre'; END IF;
END $v$;

-- 58. Única pendiente pasada identificada
DO $v$ BEGIN
 IF (SELECT count(*)<>1 OR min(c.id_consulta)<>331 OR max(c.id_consulta)<>331 AS error FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE c.estado='AGENDADA' AND t.fecha<(DATE '2026-10-27' + current_setting('demo.desplazamiento')::int)) THEN RAISE EXCEPTION 'Verificación fallida: Única pendiente pasada identificada'; END IF;
END $v$;

-- 59. Sin resultados futuros
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE t.fecha>=(DATE '2026-10-27' + current_setting('demo.desplazamiento')::int) AND c.estado<>'AGENDADA') AS error) THEN RAISE EXCEPTION 'Verificación fallida: Sin resultados futuros'; END IF;
END $v$;

-- 60. Cuatro llegadas el día D y ninguna futura
DO $v$ BEGIN
 IF (SELECT count(*) FILTER(WHERE fecha=(DATE '2026-10-27' + current_setting('demo.desplazamiento')::int))<>4 OR count(*) FILTER(WHERE fecha>(DATE '2026-10-27' + current_setting('demo.desplazamiento')::int))<>0 AS error FROM public.aviso_llegada) THEN RAISE EXCEPTION 'Verificación fallida: Cuatro llegadas el 27 y ninguna futura'; END IF;
END $v$;

-- 61. Llegadas actuales corresponden a pacientes agendados
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.aviso_llegada a WHERE a.fecha=(DATE '2026-10-27' + current_setting('demo.desplazamiento')::int) AND NOT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) WHERE c.id_socio=a.id_socio AND t.fecha=a.fecha AND c.estado='AGENDADA')) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Llegadas actuales corresponden a pacientes agendados'; END IF;
END $v$;

-- 62. Los cinco estados tienen ejemplos
DO $v$ BEGIN
 IF (SELECT count(DISTINCT estado)<>5 AS error FROM public.consulta) THEN RAISE EXCEPTION 'Verificación fallida: Los cinco estados tienen ejemplos'; END IF;
END $v$;

-- 63. Pediatría únicamente para menores
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) JOIN public.cuenta u ON u.id_cuenta=c.id_socio JOIN public.persona p ON p.ci=u.ci WHERE ts.id_especialidad=2 AND age(t.fecha,p.fecha_nacimiento)>=interval '18 years') AS error) THEN RAISE EXCEPTION 'Verificación fallida: Pediatría únicamente para menores'; END IF;
END $v$;

-- 64. Paciente, médico y funcionario son personas distintas
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.consulta c JOIN public.numero n USING(id_numero) JOIN public.turno t USING(id_turno) JOIN public.turno_semanal ts USING(id_turno_semanal) JOIN public.cuenta u ON u.id_cuenta=c.id_socio JOIN public.cuenta m ON m.id_cuenta=ts.id_medico WHERE u.ci=m.ci) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Paciente, médico y funcionario son personas distintas'; END IF;
END $v$;

-- 66. Agenda termina en D+35
DO $v$ BEGIN
 IF (SELECT max(fecha)<>(DATE '2026-12-01' + current_setting('demo.desplazamiento')::int) OR count(*) FILTER(WHERE fecha>(DATE '2026-12-01' + current_setting('demo.desplazamiento')::int))<>0 AS error FROM public.turno) THEN RAISE EXCEPTION 'Verificación fallida: Agenda termina el 1 de diciembre'; END IF;
END $v$;

-- 67. Patrones terminan en D+35
DO $v$ BEGIN
 IF (SELECT EXISTS(SELECT 1 FROM public.turno_semanal WHERE fecha_fin<>(DATE '2026-12-01' + current_setting('demo.desplazamiento')::int)) AS error) THEN RAISE EXCEPTION 'Verificación fallida: Patrones terminan el 1 de diciembre'; END IF;
END $v$;
-- Comprobaciones específicas de la reconstrucción.
DO $controles$
BEGIN
 IF (SELECT count(*) FROM public.pase p WHERE NOT EXISTS
       (SELECT FROM public.consulta c WHERE c.id_pase=p.id_pase AND c.estado NOT LIKE 'CANCELADA%')
       AND vence_el >= DATE '2026-10-27'+current_setting('demo.desplazamiento')::int) <> 4
 OR (SELECT count(*) FROM public.pase p WHERE NOT EXISTS
       (SELECT FROM public.consulta c WHERE c.id_pase=p.id_pase AND c.estado NOT LIKE 'CANCELADA%')
       AND vence_el < DATE '2026-10-27'+current_setting('demo.desplazamiento')::int) <> 4
 THEN RAISE EXCEPTION 'Se esperaban cuatro pases libres vigentes y cuatro vencidos'; END IF;
 IF EXISTS (SELECT FROM public.cuenta WHERE correo <> 'medicaoriental0+' || ci || '@gmail.com'
             OR NOT habilitada OR (NOT primer_ingreso_completado AND contrasena_hash IS NOT NULL))
 THEN RAISE EXCEPTION 'Alias o activación incorrectos'; END IF;
 IF EXISTS (SELECT FROM public.anuncio
             WHERE id_administrador IS DISTINCT FROM (SELECT min(id_cuenta) FROM public.cuenta WHERE rol='ADMINISTRADOR')
                OR vigente_hasta IS DISTINCT FROM (TIMESTAMP '2028-01-01 00:00:00' AT TIME ZONE 'America/Montevideo'))
 THEN RAISE EXCEPTION 'Autor o vigencia de cartelera incorrectos'; END IF;
END $controles$;

SELECT (DATE '2026-10-27'+current_setting('demo.desplazamiento')::int) AS fecha_base_uy,
  (SELECT count(*) FROM public.cuenta) AS cuentas, (SELECT count(*) FROM public.turno) AS turnos,
  (SELECT count(*) FROM public.numero) AS numeros, (SELECT count(*) FROM public.consulta) AS consultas,
  (SELECT count(*) FROM public.atencion) AS atenciones, (SELECT count(*) FROM public.pase) AS pases,
  (SELECT count(*) FROM public.anuncio) AS novedades, (SELECT count(*) FROM public.imagen_anuncio) AS imagenes;

COMMIT;
