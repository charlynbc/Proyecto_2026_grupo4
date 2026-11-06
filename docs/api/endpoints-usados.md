# Registro de endpoints: propuestos y usados por el frontend

Lugar en el repo: `docs/api/endpoints-usados.md`. Se mantiene a medida que avanza el frontend.

**Estado de la ruta**
- PROPUESTA: la propuso el frontend a partir del Diseño 2.1 a 2.7 (figuras 1 a 7). El backend no la confirmó.
- CONFIRMADA: el backend la implementó o la aceptó tal cual.
- CAMBIADA: el backend usa otra. Se anota la ruta nueva y qué campos cambiaron.

**Usada por el front**: `-` si todavía no hay código que la llame; si no, rama o PR y fecha. CONFIRMADA indica que existe una implementación backend en la rama de integración, no que se haya verificado el flujo end-to-end.

**Campos y errores**: cada fila enlaza a su sección de `docs/api/contrato-v1.md`, donde están los parámetros, el JSON de ejemplo, los errores y los roles. Las rutas que aún no tienen implementación conservan PROPUESTA. Las diferencias observadas con las rutas de la prueba de concepto se listan al final.

Las rutas viven todas en `frontend/lib/core/network/api_routes.dart`. Cambiar una ruta es cambiar una línea ahí, más la fila de acá.

Para los contratos verificados contra la implementación Java actual, incluidos
sus filtros, JSON y ejemplos ejecutables de consola, consultar
[`docs/manual-backend-consola.md`](../manual-backend-consola.md). CONFIRMADA
indica que existe la ruta en el backend; no acredita una prueba E2E con
PostgreSQL.

## Semana 1

| # | Método y ruta | Roles | RF | Pantalla del front | Estado | Usada por el front | Campos y errores |
|---|---|---|---|---|---|---|---|
| 1 | `POST /api/auth/login` | público | 01 | Login | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #1](contrato-v1.md#e01) |
| 2 | `POST /api/auth/refresh` | público (cookie) | 01 | Renovación de sesión | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #2](contrato-v1.md#e02) |
| 3 | `POST /api/auth/logout` | autenticado | 03 | Cerrar sesión | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #3](contrato-v1.md#e03) |
| 4 | `POST /api/auth/primer-ingreso/solicitar` | público | 02 | Pedir activación | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #4](contrato-v1.md#e04) |
| 5 | `POST /api/auth/primer-ingreso/completar` | público (token) | 02 | Activar cuenta | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #5](contrato-v1.md#e05) |
| 6 | `GET /api/especialidades` | autenticado | 29 | Formularios y listado; consulta con filtros RF-36 (`nombre` hasta 120, `requierePase` true o false, `orden` nombre o fechaAlta, siempre ascendente, sin paginación) | CONFIRMADA | feat/front-admin 19/10/2026; feat/front-funcionario 20/10/2026; feat/front-filtrar-especialidades 02/11/2026 | [contrato #6](contrato-v1.md#e06) |
| 7 | `POST /api/especialidades` | ADMINISTRADOR | 29 | Alta de especialidad | CONFIRMADA | feat/front-admin 19/10/2026 | [contrato #7](contrato-v1.md#e07) |
| 8 | `GET /api/consultorios` | autenticado | 33 | Formularios y listado; consulta con filtros RF-37 (`nombre` hasta 120, `ubicacion` hasta 200, `orden` nombre o ubicacion, siempre ascendente, sin paginación) | CONFIRMADA | feat/front-admin 19/10/2026; feat/front-funcionario 20/10/2026; feat/front-filtrar-consultorios 03/11/2026 | [contrato #8](contrato-v1.md#e08) |
| 9 | `POST /api/consultorios` | ADMINISTRADOR | 33 | Alta de consultorio | CONFIRMADA | feat/front-admin 19/10/2026 | [contrato #9](contrato-v1.md#e09) |
| 10 | `GET /api/medicos?especialidadId=` | SOCIO, FUNCIONARIO | 13, 08 | Selector de médico (filtro opcional; el socio ve todos los médicos activos y solo campos mínimos). En Flutter lo usa el selector de médico de la pantalla de disponibilidad del socio (RF-08): se pide una vez al abrir y se filtra en el cliente | CONFIRMADA | feat/front-disponibilidad-medico 05/11/2026 | [contrato #10](contrato-v1.md#e10) |
| 11 | `POST /api/usuarios` | ADMINISTRADOR | 31 | Alta de usuario | CONFIRMADA | feat/front-admin 19/10/2026 | [contrato #11](contrato-v1.md#e11) |
| 12 | `GET /api/usuarios` | ADMINISTRADOR | 35 | Consulta de usuarios (`rol`, `estado` ACTIVA o INACTIVA, `q` CI o apellido, `orden` apellido o fechaAlta, `sentido` asc o desc, `page` desde 0, `size` de 1 a 100, por defecto 20) | CONFIRMADA | feat/front-admin 19/10/2026 | [contrato #12](contrato-v1.md#e12) |
| 13 | `POST /api/turnos-semanales` | FUNCIONARIO | 13 | Alta de turno semanal | CONFIRMADA | feat/front-funcionario 20/10/2026 | [contrato #13](contrato-v1.md#e13) |
| 14 | `GET /api/turnos-semanales/{id}` | FUNCIONARIO | 17 | Detalle de configuración | CONFIRMADA | feat/front-funcionario 20/10/2026 | [contrato #14](contrato-v1.md#e14) |
| 15 | `GET /api/turnos` | FUNCIONARIO | 17 | Consulta de turnos | CONFIRMADA | feat/front-funcionario 20/10/2026 | [contrato #15](contrato-v1.md#e15) |
| 16 | `GET /api/disponibilidad` | SOCIO | 08 | Disponibilidad (especialidadId o medicoId, al menos uno) | CONFIRMADA | Sin POC: agenda Flutter; feat/front-disponibilidad-medico 05/11/2026 (búsqueda por médico, por especialidad o por ambos) | [contrato #16](contrato-v1.md#e16) |
| 17 | `POST /api/consultas` | SOCIO | 09 | Confirmar agenda | CONFIRMADA | Sin POC: agenda Flutter | [contrato #17](contrato-v1.md#e17) |

## Semana 2 y adelantos

| # | Método y ruta | Roles | RF | Pantalla del front | Estado | Usada por el front | Campos y errores |
|---|---|---|---|---|---|---|---|
| 18 | `GET /api/consultas` | SOCIO | 11 | Mis consultas | CONFIRMADA | integracion/proyecto-2026-avances 22/10/2026 | [contrato #18](contrato-v1.md#e18) |
| 19 | `GET /api/consultas/{id}` | SOCIO | 11 | Detalle de consulta | CONFIRMADA | integracion/proyecto-2026-avances 22/10/2026 | [contrato #19](contrato-v1.md#e19) |
| 20 | `POST /api/consultas/{id}/cancelar` | SOCIO | 10 | Cancelar consulta | CONFIRMADA | rama feat/cierre-cancelaciones-pases | [contrato #20](contrato-v1.md#e20) |
| 21 | `GET /api/historia-clinica` | SOCIO (solo propias) | 12 | Historia clínica | CONFIRMADA | - | [contrato #21](contrato-v1.md#e21) |
| 22 | `GET /api/historia-clinica/{idAtencion}` | SOCIO (solo propias) | 12 | Detalle de atención | CONFIRMADA | - | [contrato #22](contrato-v1.md#e22) |
| 23 | `POST /api/turnos/suspensiones/previsualizar` | FUNCIONARIO | 14 | Confirmación previa (pantalla Flutter `/funcionario/turnos/suspender`) | CONFIRMADA | Backend en integracion/proyecto-2026-avances; Flutter rama feat/front-suspender-turnos 29/10/2026 | [contrato #23](contrato-v1.md#e23) |
| 24 | `POST /api/turnos/suspensiones` | FUNCIONARIO | 14 | Suspender fechas (pantalla Flutter `/funcionario/turnos/suspender`) | CONFIRMADA | Backend en integracion/proyecto-2026-avances; Flutter rama feat/front-suspender-turnos 29/10/2026 | [contrato #24](contrato-v1.md#e24) |
| 25 | `POST /api/turnos/rehabilitaciones` | FUNCIONARIO | 15 | Rehabilitar fechas | CONFIRMADA | feat/front-rehabilitar-turnos 29/10/2026 | [contrato #25](contrato-v1.md#e25) |
| 26 | `GET /api/avisos-llegada/consultas-hoy?ci=` | FUNCIONARIO | 16 | Buscar socio | CONFIRMADA | - | [contrato #26](contrato-v1.md#e26) |
| 27 | `POST /api/avisos-llegada` | FUNCIONARIO | 16 | Registrar llegada | CONFIRMADA | - | [contrato #27](contrato-v1.md#e27) |
| 28 | `GET /api/agendas` | FUNCIONARIO | 18 | Consulta de agendas | CONFIRMADA | Backend en integracion/proyecto-2026-avances 23/10/2026; Flutter pendiente | [contrato #28](contrato-v1.md#e28) |
| 29 | `GET /api/medico/turnos?fecha=` | MEDICO | 21 | Mis turnos (pantalla Flutter `/medico/turnos`, sondeo cada 15 s, PR #39) | CONFIRMADA | - | [contrato #29](contrato-v1.md#e29) |
| 30 | `GET /api/medico/turnos/{id}/numeros` | MEDICO | 21, 22 | Pacientes del turno (`consulta.paciente.id` para abrir historia #40; con `llegada`, `orden`, `sentido`; sondeo cada 15 s) | CONFIRMADA | - | [contrato #30](contrato-v1.md#e30) |
| 31 | `POST /api/medico/consultas/{id}/resultado` | MEDICO | 23, 24 | Registrar atención y pases (pantalla Flutter `/medico/consultas/:id/resultado`) | CONFIRMADA | PR #40 | [contrato #31](contrato-v1.md#e31) |
| 32 | `GET /api/notificaciones` | SOCIO | RNF-23 | Lista de notificaciones | PROPUESTA | - | [contrato #32](contrato-v1.md#e32) |
| 33 | `POST /api/dispositivos` | SOCIO | RNF-23 | Registro de token push | CAMBIADA | - | [contrato #33](contrato-v1.md#e33) |
| 34 | `GET /api/estadisticas/especialidades` | ADMINISTRADOR | 39 | Estadísticas | CONFIRMADA (integrada en avances, PR #24) | - | [contrato #34](contrato-v1.md#e34) |
| 35 | `GET /api/estadisticas/turnos` | ADMINISTRADOR | 40 | Estadísticas | CONFIRMADA (integrada en avances, PR #25; agrega `fechasActivas` y `utilizacion`; interpretación histórica desde `turno_evento` en el PR #38, JSON sin cambios) | - | [contrato #35](contrato-v1.md#e35) |
| 36 | `GET /api/estadisticas/consultas` | ADMINISTRADOR | 41 | Estadísticas | CONFIRMADA (integrada en avances; usa `estados`, `totalConsultas`, `canceladasPorSocio`, `porcentajeCancelacion` y `porcentajeCancelacionTexto`) | - | [contrato #36](contrato-v1.md#e36) |
| 37 | `GET /api/socios/me/pases/disponibles` | SOCIO | 09 | Confirmar agenda (pase que se usará) | CONFIRMADA | feat/front-socio-sobre-integracion 25/10/2026 | Sin sección en el contrato (P-08 sigue diciendo que no hay endpoint). Ver "Cambios de campos acordados". |
| 38 | `POST /api/medico/consultas/{id}/cancelar` | MEDICO | 27 | Cancelar una consulta del médico (motivo obligatorio) | CONFIRMADA | - | [contrato #38](contrato-v1.md#e38) |
| 39 | `POST /api/medico/turnos/{id}/cancelar` | MEDICO | 27 | Cancelar todo el turno de una fecha y suspenderla (motivo obligatorio) | CONFIRMADA | - | [contrato #39](contrato-v1.md#e39) |
| 40 | `GET /api/medico/pacientes/{socioId}/historia-clinica` | MEDICO | 22 | Historia clínica previa del paciente (requiere consulta AGENDADA vigente con él) | CONFIRMADA | - | [contrato #40](contrato-v1.md#e40) |
| 41 | `GET /api/medico/atenciones` | MEDICO | 25 | Consultas atendidas por el médico (`fechaDesde`/`fechaHasta` obligatorias; `paciente`, `especialidadId`, `orden`, `sentido`) | CONFIRMADA | - | [contrato #41](contrato-v1.md#e41) |
| 42 | `GET /api/medico/atenciones/{idAtencion}` | MEDICO | 25 | Detalle de una atención propia | CONFIRMADA | - | [contrato #42](contrato-v1.md#e42) |
| 43 | `GET /api/medico/pases` | MEDICO | 26 | Pases emitidos por el médico (`situacion`, `orden`, `sentido`) | CONFIRMADA | - | [contrato #43](contrato-v1.md#e43) |
| 44 | `POST /api/funcionario/consultas/{id}/cancelar` | FUNCIONARIO | 19 | Cancelar consulta a pedido del socio | CONFIRMADA | - | [contrato #44](contrato-v1.md#e44) |
| 45 | `POST /api/auth/cambiar-contrasena` | autenticado | 04 | Cambio de contraseña | CONFIRMADA (backend 01/11/2026, rama feat/rf-04-06-05-20) | - | [contrato #45](contrato-v1.md#e45) |
| 46 | `GET /api/cuentas/me` | autenticado | 06 | Datos personales (precarga del formulario) | CONFIRMADA (backend 01/11/2026, rama feat/rf-04-06-05-20) | - | [contrato #46](contrato-v1.md#e46) |
| 47 | `PATCH /api/cuentas/me` | autenticado | 06 | Edición de datos personales; el correo queda pendiente de confirmación | CONFIRMADA (backend 01/11/2026, rama feat/rf-04-06-05-20) | - | [contrato #47](contrato-v1.md#e47) |
| 48 | `POST /api/auth/recuperacion/solicitar` | público | 05 | Pedir recuperación de contraseña | CONFIRMADA (backend 01/11/2026, rama feat/rf-04-06-05-20; correo verificado solo con proveedor simulado/Mailpit, falta Resend real) | feat/front-recuperar-contrasena 03/11/2026 | [contrato #48](contrato-v1.md#e48) |
| 49 | `POST /api/auth/recuperacion/completar` | público (token) | 05 | Definir contraseña nueva | CONFIRMADA (backend 01/11/2026, rama feat/rf-04-06-05-20) | feat/front-recuperar-contrasena 03/11/2026 | [contrato #49](contrato-v1.md#e49) |
| 50 | `POST /api/auth/cambio-correo/confirmar` | público (token) | 06 | Confirmar correo nuevo | CONFIRMADA (backend 01/11/2026, rama feat/rf-04-06-05-20) | feat/front-confirmar-cambio-correo 04/11/2026 | [contrato #50](contrato-v1.md#e50) |
| 51 | `PATCH /api/turnos-semanales/{id}` | FUNCIONARIO | 20 | Modificar el consultorio del turno semanal | CONFIRMADA (backend 01/11/2026, rama feat/rf-04-06-05-20) | - | [contrato #51](contrato-v1.md#e51) |
| 52 | `POST /api/especialidades/importaciones/previsualizar` | ADMINISTRADOR | 30 | Carga masiva de especialidades (vista previa) | CONFIRMADA (backend 02/11/2026, rama feat/rf-30-32-cargas-masivas) | - | [contrato #52](contrato-v1.md#e52) |
| 53 | `POST /api/especialidades/importaciones/confirmar` | ADMINISTRADOR | 30 | Carga masiva de especialidades (importa válidas) | CONFIRMADA (backend 02/11/2026, rama feat/rf-30-32-cargas-masivas) | - | [contrato #53](contrato-v1.md#e53) |
| 54 | `POST /api/usuarios/importaciones/previsualizar` | ADMINISTRADOR | 32 | Carga masiva de usuarios (vista previa) | CONFIRMADA (backend 02/11/2026, rama feat/rf-30-32-cargas-masivas) | feat/front-usuarios-importar 05/11/2026 | [contrato #54](contrato-v1.md#e54) |
| 55 | `POST /api/usuarios/importaciones/confirmar` | ADMINISTRADOR | 32 | Carga masiva de usuarios (importa válidas) | CONFIRMADA (backend 02/11/2026, rama feat/rf-30-32-cargas-masivas) | feat/front-usuarios-importar 05/11/2026 | [contrato #55](contrato-v1.md#e55) |
| 56 | `POST /api/consultorios/importaciones/previsualizar` | ADMINISTRADOR | 34 | Carga masiva de consultorios (vista previa) | CONFIRMADA (backend 04/11/2026, rama feat/rf-34-38-cierre) | - | [contrato #56](contrato-v1.md#e56) |
| 57 | `POST /api/consultorios/importaciones/confirmar` | ADMINISTRADOR | 34 | Carga masiva de consultorios (importa válidas) | CONFIRMADA (backend 04/11/2026, rama feat/rf-34-38-cierre) | - | [contrato #57](contrato-v1.md#e57) |
| 58 | `PATCH /api/usuarios/{id}` | ADMINISTRADOR | 38 | Corrección de datos de la cuenta (CI, nombre, apellido, fecha de nacimiento, correo, teléfonos, dirección, especialidades; nunca el rol) | CONFIRMADA (backend 04/11/2026, rama feat/rf-34-38-cierre) | - | [contrato #58](contrato-v1.md#e58) |
| 59 | `PATCH /api/especialidades/{id}` | ADMINISTRADOR | 38 | Corrección de nombre y exigencia de pase | CONFIRMADA (backend 04/11/2026, rama feat/rf-34-38-cierre) | - | [contrato #59](contrato-v1.md#e59) |
| 60 | `PATCH /api/consultorios/{id}` | ADMINISTRADOR | 38 | Corrección de nombre y ubicación | CONFIRMADA (backend 04/11/2026, rama feat/rf-34-38-cierre) | - | [contrato #60](contrato-v1.md#e60) |
| 61 | `POST /api/usuarios/{id}/inactivar` | ADMINISTRADOR | 45 | Inactivar cuenta de empleado, conservando historial y registrando auditoría | CONFIRMADA (backend 04/11/2026, integración RF-45) | - | [contrato #61](contrato-v1.md#e61) |
| 62 | `POST /api/usuarios/{id}/reactivar` | ADMINISTRADOR | 45 | Reactivar cuenta de empleado sin habilitar turnos suspendidos; evita duplicidad | CONFIRMADA (backend 04/11/2026, integración RF-45) | - | [contrato #62](contrato-v1.md#e62) |
| 63 | `POST /api/auth/primer-ingreso/validar` | público (token) | 02 | Comprobar el enlace antes de pedir los datos, sin consumirlo | IMPLEMENTADA EN BACKEND (PR #75) | - | [contrato #63](contrato-v1.md#e63) |
| 64 | `POST /api/auth/recuperacion/validar` | público (token) | 05 | Comprobar el enlace antes de pedir contraseña, sin consumirlo | IMPLEMENTADA EN BACKEND (PR #75) | - | [contrato #64](contrato-v1.md#e64) |
| 65 | `POST /api/anuncios` | ADMINISTRADOR | 28 | Publicar novedad con título y contenido de texto, imágenes o ambos | IMPLEMENTADA EN BACKEND (PR #71) | - | [contrato #65](contrato-v1.md#e65) |
| 66 | `GET /api/anuncios` | autenticado | 07 | Tarjetas para el inicio y la cartelera, con portada opcional | IMPLEMENTADA EN BACKEND (PR #71) | - | [contrato #66](contrato-v1.md#e66) |
| 67 | `GET /api/anuncios/{id}` | autenticado | 07 | Detalle de novedad con texto y/o imágenes ordenadas | IMPLEMENTADA EN BACKEND (PR #71) | - | [contrato #67](contrato-v1.md#e67) |
| 68 | `GET /api/usuarios/{id}` | ADMINISTRADOR | 38 | Detalle completo de cuenta para precargar corrección; mismo DTO que PATCH #58 | CONFIRMADA (backend 06/11/2026) | - | [contrato #68](contrato-v1.md#e68) |

## Rutas de la prueba de concepto

El backend **ya no las expone** (commit "Sin POC") y el frontend dejó de
llamarlas: la agenda del socio usa `GET /api/especialidades`,
`GET /api/disponibilidad` y `POST /api/consultas` (el alta se hace por
`numeroId`, con `paseId` opcional). Las tablas del esquema `"POC"` no se
migran: se usa solo el modelo del Proyecto 2026.

| Ruta eliminada del backend | La reemplaza | Estado |
|---|---|---|
| `POST /api/auth/login` con `{cedula, clave}` | #1, con `{ci, password, acceso}` (+ `plataforma: WEB` para `EMPLEADO`) | eliminada; el login solo acepta el contrato nuevo |
| POST /api/auth/registro | #11 `POST /api/usuarios` (RF-31, solo ADMINISTRADOR) | eliminada; no hay alta pública |
| GET /api/auth/confirmar-email | #4 y #5 (`primer-ingreso`, RF-02) | eliminada |
| GET /api/profesionales | #10 `GET /api/medicos` | Implementado; permite SOCIO y FUNCIONARIO. Lista todos los médicos activos, tengan o no números libres; el socio recibe solo nombre, apellido, id y especialidades (id, nombre) |
| GET /api/profesionales/{id}/horarios | #16 `GET /api/disponibilidad` | migrado en Flutter |
| POST /api/reservas | #17 `POST /api/consultas` | migrado en Flutter (reserva por `numeroId`) |
| GET /api/mis-reservas | #18 `GET /api/consultas` (RF-11) | migrado en backend y Flutter; usa filtros y paginación del contrato |
| PATCH /api/reservas/{id}/cancelacion | #20 `POST /api/consultas/{id}/cancelar` | Implementado en backend; el frontend debe habilitar la acción |
| `POST /api/notificaciones/registro` | #33 | se mantiene (no usa el esquema `"POC"`) |

La ruta de registro de notificaciones que existe en el backend es
`POST /api/notificaciones/registro`; no se implementó la ruta contractual
`POST /api/dispositivos`.

## Endpoint adicional verificado

`GET /api/socios/me/pases/disponibles` está implementado para el rol `SOCIO`.
Obtiene la identidad del `sub` del JWT y devuelve solo pases disponibles del
titular. Su contrato y ejemplos de consola están en
[`docs/manual-backend-consola.md`](../manual-backend-consola.md).

## Contratos verificados en backend

Al 26/10/2026, el backend implementa las rutas #10, #12, #18, #21, #22, #28 y
`GET /api/socios/me/pases/disponibles`. La implementación actual es la fuente
de verdad para las consultas de consola y puede diferir de propuestas previas
en `contrato-v1.md`: por ejemplo,
`GET /api/historia-clinica` devuelve una lista sin paginar con los campos
clínicos permitidos (decisión documentada en contrato #21: RF-12 no exige paginación). Ver el manual enlazado
arriba para el contrato real y ejemplos.

## Cambios de campos acordados con el backend

- 05/11/2026, #55: la respuesta de confirmar la carga masiva de usuarios incluye `total` (entero, cantidad de filas del archivo), que el contrato no lista en esa respuesta pero el backend devuelve. El frontend lo lee y, si faltara, lo calcula como `importadas` más `rechazadas`. El cliente manda el archivo en el campo `archivo` (multipart) en #54 y en #55, y conserva los bytes entre las dos llamadas. Usado en `feat/front-usuarios-importar`.

- 03/11/2026, #63 y #64: nuevos `POST /api/auth/primer-ingreso/validar` y `POST /api/auth/recuperacion/validar`, cuerpo `{"token":"…"}`. Públicos, `200` sin cuerpo si el enlace está vigente; `400 ENLACE_INVALIDO` con el mensaje actual para cualquier enlace inválido, sin distinguir el motivo. Solo lectura, repetibles, no consumen ni reservan el enlace. El frontend debe conservar el manejo de `ENLACE_INVALIDO` al completar (#5 y #49). Implementados en el PR #75.

- 31/10/2026, #30: `consulta.paciente` agrega `id` (entero, identificador de cuenta del socio) sin eliminar `ci`, `nombre` ni `apellido`. El frontend debe usar `consulta.paciente.id` como `{socioId}` en #40 para RF-22. Los números libres conservan `consulta: null`.

- 25/10/2026, #37: la ruta de pases disponibles no tiene sección propia en el contrato. El backend (`PaseController`, rama de integración) responde una lista de `PaseDTO` con `{id, especialidadDestino: {id, nombre, requierePase}, emitidoEn, venceEl}`; `emitidoEn` es fecha y hora con offset y `venceEl` es una fecha `aaaa-mm-dd`. Responde 401 `TOKEN_INVALIDO` si el identificador del token no es válido.
