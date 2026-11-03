# Pendientes para cerrar los RF críticos

Este plan deriva de la auditoría en
[`auditoria-backend-criticos.md`](./auditoria-backend-criticos.md), sobre
`integracion/proyecto-2026-avances` en
`280a7e4ad5426d243cd8dd233e47193d2af98729`. Es un inventario de trabajo
posterior; no implementa cambios ni autoriza despliegues.

## Orden recomendado

### 1. RF-02 — corregir el caso de cuenta activa

**Prioridad inmediata.** La aceptación exige que al solicitar primer ingreso
para una cuenta ya activa se remita un correo con indicaciones para recuperar
la contraseña, manteniendo la misma respuesta genérica que para una CI
inexistente. Actualmente no se envía correo y una prueba espera ese resultado.

Antes de modificar código, definir si el correo debe incluir directamente un
enlace de recuperación o limitarse a explicar el flujo RF-05; la especificación
indica instrucciones de recuperación pero el RF-05 completo queda fuera del
alcance crítico de esta auditoría. Cambiar juntos el comportamiento y las
pruebas de unidad/HTTP, verificar ambos accesos y preservar la protección
contra enumeración. Luego probar con PostgreSQL aislado:

- CI no registrada: respuesta genérica, sin correo.
- cuenta pendiente: respuesta genérica, enlace de primer ingreso al correo
  del padrón.
- cuenta activa: misma respuesta genérica y correo de instrucciones de
  recuperación.
- cuenta inactivada: sin activación posible ni reactivación por enlace.
- enlaces expirados, sustituidos, reutilizados y completados concurrentemente.

### 2. RF-39 — demanda de consultas por especialidad

Implementar el primer reporte estadístico ausente. La agregación debe usar
`consulta.agendada_en` dentro del rango y contar consultas por especialidad,
incluyendo consultas que luego se cancelaron. Proteger la ruta para
ADMINISTRADOR; validar límites de fechas, orden/agrupación, período vacío y
filtros del contrato aprobado. Añadir pruebas de consulta SQL en PostgreSQL
descartable, además de pruebas unitarias y HTTP/roles.

### 3. RF-40 — utilización por turno

Definir y probar numerador y denominador antes de exponer el reporte:

- denominador: números ofrecidos de las fechas del período en que el turno
  estuvo activo;
- numerador: números con consulta en los estados definidos por RF-40;
- cancelaciones dejan el número libre;
- estados `NO_ASISTIO` y `NO_ATENDIDA` son derivados según fecha y aviso de
  llegada; no agregar como si fueran estados persistidos.

Cubrir turnos con cero números aplicables, suspensiones, fechas fuera de rango
y porcentajes/“Sin datos” conforme al criterio del requerimiento. Verificar
resultados con PostgreSQL.

### 4. RF-41 — cantidades y tasa de cancelación

Agregar conteos por fecha de consulta para los siete estados indicados por
RF-41 y la tasa de cancelación por el socio. La consulta debe distinguir:

- cero consultas: “Sin datos”;
- consultas existentes y ninguna cancelación por socio: 0 %;
- cancelaciones por socio y por institución, separadas correctamente.

Usar estados derivados con la misma regla temporal que RF-11/RF-18/RF-40.
Probar en PostgreSQL y cubrir autorización de ADMINISTRADOR.

### 5. Validación transversal antes de considerar cierre

1. Configurar una instancia PostgreSQL **descartable y aislada**, con nombre
   terminado en `_e2e` o `_test` y las guardas requeridas por
   `BaseIntegracionIT`; nunca apuntar a una base de desarrollo compartida o
   producción.
2. Ejecutar explícitamente las pruebas `*IT` de autenticación, reservas,
   suspensiones/rehabilitaciones, llegada, atención, pases y concurrencia.
   `maven-surefire-plugin` no las incluye por convención y el POM actual no
   configura Failsafe; identificar y registrar el comando/perfil real que las
   ejecuta sin debilitar las guardas.
3. Ejecutar nuevamente `.\mvnw.cmd -B verify` y registrar cantidades exactas.
4. Ejecutar flujos HTTP autenticados de cada RF corregido/nuevo y luego
   recorridos desde frontend; mantenerlos como pendientes hasta tener evidencia.
5. Revisar el contrato API y actualizar documentación de endpoints solo cuando
   la implementación se haya aprobado. No describir propuestas como rutas
   existentes.

## Dependencias y criterios de aceptación

| Trabajo | Depende de | No cerrar hasta |
|---|---|---|
| RF-02 | Aclarar el contenido/alcance del correo de recuperación frente a RF-05. | La prueba confirme la respuesta anti-enumeración y el envío de correo según estado; cuenta inactivada y enlace de un solo uso probados en PostgreSQL. |
| RF-39 | Contrato de período y agrupación por especialidad. | SQL demuestra uso de fecha de agendamiento e inclusión de canceladas; roles, fechas límite y vacío probados. |
| RF-40 | Regla consistente de estados derivados y fecha de actividad del turno. | Numerador/denominador reproducidos desde datos de prueba; cancelación y suspensión no inflan ocupación. |
| RF-41 | Regla consistente de estados derivados y semántica “Sin datos”/0 %. | Conteos de siete categorías y denominador cero/positivo verificados en PostgreSQL. |
| Cierre transversal | Base de pruebas aislada, guardas activas y ejecución explícita de IT. | Suite Maven, IT PostgreSQL y E2E/frontend informados por separado; ningún dato clínico real. |

## Primer paso sugerido

Completar primero **RF-02**, porque hay una discrepancia concreta entre
requerimiento y comportamiento implementado que afecta un flujo de acceso y
una prueba actual codifica la regla contraria. Inmediatamente después, abordar
**RF-39** como primer requerimiento estadístico, ya que es una funcionalidad
completamente ausente y establece el patrón de autorización/agregación para
RF-40 y RF-41.
