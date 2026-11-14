-- Cuenta los envios de notificacion que siguen PENDIENTES, por tipo de aviso y
-- por canal. Solo lee: no modifica ni borra nada.
--
-- Para que correrlo antes del despliegue de "el despacho envia avisos de todos
-- los tipos". Hasta ahora el despacho solo tomaba los envios de SUSPENSION, asi
-- que los de CANCELACION quedaron PENDIENTE para siempre. Con el cambio, el
-- poller (cada 30 s, hasta 100 por ciclo) los empieza a enviar todos, incluso
-- los viejos: el socio podria recibir de golpe correos o push de cancelaciones
-- antiguas. Este conteo dice cuantos son y de cuando.
--
-- Correrlo en la base de pruebas y en la de produccion. Si hay pendientes
-- viejos que no conviene enviar, la limpieza la decide y la hace quien
-- administra la base (Martin), no esta tarea.
--
-- Uso:  psql -f database/pruebas/contar_envios_pendientes.sql

-- Pendientes por tipo de aviso y canal, con la fecha del mas antiguo.
SELECT notificacion.tipo,
       envio.canal,
       count(*) AS pendientes,
       min(notificacion.creada_en) AS mas_antiguo
FROM public.envio_notificacion envio
JOIN public.notificacion notificacion
  ON notificacion.id_notificacion = envio.id_notificacion
WHERE envio.estado = 'PENDIENTE'
GROUP BY notificacion.tipo, envio.canal
ORDER BY notificacion.tipo, envio.canal;

-- Total de pendientes.
SELECT count(*) AS total_pendientes
FROM public.envio_notificacion
WHERE estado = 'PENDIENTE';
