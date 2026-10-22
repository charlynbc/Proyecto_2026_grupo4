# Registro de endpoints: propuestos y usados por el frontend

Lugar en el repo: `docs/api/endpoints-usados.md`. Se mantiene a medida que avanza el frontend.

**Estado de la ruta**
- PROPUESTA: la propuso el frontend a partir del Diseño 2.1 a 2.7 (figuras 1 a 7). El backend no la confirmó.
- CONFIRMADA: el backend la implementó o la aceptó tal cual.
- CAMBIADA: el backend usa otra. Se anota la ruta nueva y qué campos cambiaron.

**Usada por el front**: `-` si todavía no hay código que la llame; si no, rama o PR y fecha. CONFIRMADA indica que existe una implementación backend en la rama de integración, no que se haya verificado el flujo end-to-end.

**Campos y errores**: cada fila enlaza a su sección de `docs/api/contrato-v1.md`, donde están los parámetros, el JSON de ejemplo, los errores y los roles. Las rutas que aún no tienen implementación conservan PROPUESTA. Las diferencias observadas con las rutas de la prueba de concepto se listan al final.

Las rutas viven todas en `frontend/lib/core/network/api_routes.dart`. Cambiar una ruta es cambiar una línea ahí, más la fila de acá.

## Semana 1

| # | Método y ruta | Roles | RF | Pantalla del front | Estado | Usada por el front | Campos y errores |
|---|---|---|---|---|---|---|---|
| 1 | `POST /api/auth/login` | público | 01 | Login | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #1](contrato-v1.md#e01) |
| 2 | `POST /api/auth/refresh` | público (cookie) | 01 | Renovación de sesión | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #2](contrato-v1.md#e02) |
| 3 | `POST /api/auth/logout` | autenticado | 03 | Cerrar sesión | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #3](contrato-v1.md#e03) |
| 4 | `POST /api/auth/primer-ingreso/solicitar` | público | 02 | Pedir activación | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #4](contrato-v1.md#e04) |
| 5 | `POST /api/auth/primer-ingreso/completar` | público (token) | 02 | Activar cuenta | CONFIRMADA | feat/front-acceso-roles 14/10/2026 | [contrato #5](contrato-v1.md#e05) |
| 6 | `GET /api/especialidades` | autenticado | 29 | Formularios y listado | CONFIRMADA | feat/front-admin 19/10/2026; feat/front-funcionario 20/10/2026 | [contrato #6](contrato-v1.md#e06) |
| 7 | `POST /api/especialidades` | ADMINISTRADOR | 29 | Alta de especialidad | CONFIRMADA | feat/front-admin 19/10/2026 | [contrato #7](contrato-v1.md#e07) |
| 8 | `GET /api/consultorios` | autenticado | 33 | Formularios y listado | CONFIRMADA | feat/front-admin 19/10/2026; feat/front-funcionario 20/10/2026 | [contrato #8](contrato-v1.md#e08) |
| 9 | `POST /api/consultorios` | ADMINISTRADOR | 33 | Alta de consultorio | CONFIRMADA | feat/front-admin 19/10/2026 | [contrato #9](contrato-v1.md#e09) |
| 10 | `GET /api/medicos?especialidadId=` | autenticado | 13, 08 | Selector de médico | PROPUESTA | feat/front-funcionario 20/10/2026 | [contrato #10](contrato-v1.md#e10) |
| 11 | `POST /api/usuarios` | ADMINISTRADOR | 31 | Alta de usuario | CONFIRMADA | feat/front-admin 19/10/2026 | [contrato #11](contrato-v1.md#e11) |
| 12 | `GET /api/usuarios` | ADMINISTRADOR | 35 | Consulta de usuarios | PROPUESTA | feat/front-admin 19/10/2026 | [contrato #12](contrato-v1.md#e12) |
| 13 | `POST /api/turnos-semanales` | FUNCIONARIO | 13 | Alta de turno semanal | CONFIRMADA | feat/front-funcionario 20/10/2026 | [contrato #13](contrato-v1.md#e13) |
| 14 | `GET /api/turnos-semanales/{id}` | FUNCIONARIO | 17 | Detalle de configuración | CONFIRMADA | feat/front-funcionario 20/10/2026 | [contrato #14](contrato-v1.md#e14) |
| 15 | `GET /api/turnos` | FUNCIONARIO | 17 | Consulta de turnos | CONFIRMADA | feat/front-funcionario 20/10/2026 | [contrato #15](contrato-v1.md#e15) |
| 16 | `GET /api/disponibilidad` | SOCIO | 08 | Disponibilidad | CONFIRMADA | Sin POC: agenda Flutter | [contrato #16](contrato-v1.md#e16) |
| 17 | `POST /api/consultas` | SOCIO | 09 | Confirmar agenda | CONFIRMADA | Sin POC: agenda Flutter | [contrato #17](contrato-v1.md#e17) |

## Semana 2 y adelantos

| # | Método y ruta | Roles | RF | Pantalla del front | Estado | Usada por el front | Campos y errores |
|---|---|---|---|---|---|---|---|
| 18 | `GET /api/consultas` | SOCIO | 11 | Mis consultas | PROPUESTA | - | [contrato #18](contrato-v1.md#e18) |
| 19 | `GET /api/consultas/{id}` | SOCIO | 11 | Detalle de consulta | PROPUESTA | - | [contrato #19](contrato-v1.md#e19) |
| 20 | `POST /api/consultas/{id}/cancelar` | SOCIO | 10 | Cancelar consulta | PROPUESTA | - | [contrato #20](contrato-v1.md#e20) |
| 21 | `GET /api/historia-clinica` | SOCIO | 12 | Historia clínica | PROPUESTA | - | [contrato #21](contrato-v1.md#e21) |
| 22 | `GET /api/historia-clinica/{idAtencion}` | SOCIO | 12 | Detalle de atención | PROPUESTA | - | [contrato #22](contrato-v1.md#e22) |
| 23 | `POST /api/turnos/suspensiones/previsualizar` | FUNCIONARIO | 14 | Confirmación previa | PROPUESTA | - | [contrato #23](contrato-v1.md#e23) |
| 24 | `POST /api/turnos/suspensiones` | FUNCIONARIO | 14 | Suspender fechas | PROPUESTA | - | [contrato #24](contrato-v1.md#e24) |
| 25 | `POST /api/turnos/rehabilitaciones` | FUNCIONARIO | 15 | Rehabilitar fechas | PROPUESTA | - | [contrato #25](contrato-v1.md#e25) |
| 26 | `GET /api/avisos-llegada/consultas-hoy?ci=` | FUNCIONARIO | 16 | Buscar socio | CONFIRMADA | - | [contrato #26](contrato-v1.md#e26) |
| 27 | `POST /api/avisos-llegada` | FUNCIONARIO | 16 | Registrar llegada | CONFIRMADA | - | [contrato #27](contrato-v1.md#e27) |
| 28 | `GET /api/agendas` | FUNCIONARIO | 18 | Consulta de agendas | PROPUESTA | - | [contrato #28](contrato-v1.md#e28) |
| 29 | `GET /api/medico/turnos?fecha=` | MEDICO | 21 | Mis turnos | CONFIRMADA | - | [contrato #29](contrato-v1.md#e29) |
| 30 | `GET /api/medico/turnos/{id}/numeros` | MEDICO | 21 | Pacientes del turno | CONFIRMADA | - | [contrato #30](contrato-v1.md#e30) |
| 31 | `POST /api/medico/consultas/{id}/resultado` | MEDICO | 23, 24 | Registrar atención y pases | CONFIRMADA | - | [contrato #31](contrato-v1.md#e31) |
| 32 | `GET /api/notificaciones` | SOCIO | RNF-23 | Lista de notificaciones | PROPUESTA | - | [contrato #32](contrato-v1.md#e32) |
| 33 | `POST /api/dispositivos` | SOCIO | RNF-23 | Registro de token push | CAMBIADA | - | [contrato #33](contrato-v1.md#e33) |
| 34 | `GET /api/estadisticas/especialidades` | ADMINISTRADOR | 39 | Estadísticas | PROPUESTA | - | [contrato #34](contrato-v1.md#e34) |
| 35 | `GET /api/estadisticas/turnos` | ADMINISTRADOR | 40 | Estadísticas | PROPUESTA | - | [contrato #35](contrato-v1.md#e35) |
| 36 | `GET /api/estadisticas/consultas` | ADMINISTRADOR | 41 | Estadísticas | PROPUESTA | - | [contrato #36](contrato-v1.md#e36) |

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
| GET /api/profesionales | #10 `GET /api/medicos` | **Pendiente de implementación** en el backend. La disponibilidad ofrece solo los médicos con números libres |
| GET /api/profesionales/{id}/horarios | #16 `GET /api/disponibilidad` | migrado en Flutter |
| POST /api/reservas | #17 `POST /api/consultas` | migrado en Flutter (reserva por `numeroId`) |
| GET /api/mis-reservas | #18 `GET /api/consultas` (RF-11) | **Pendiente de implementación**; la pantalla lo indica |
| PATCH /api/reservas/{id}/cancelacion | #20 `POST /api/consultas/{id}/cancelar` | **Pendiente de implementación**; acción deshabilitada |
| `POST /api/notificaciones/registro` | #33 | se mantiene (no usa el esquema `"POC"`) |

La ruta de registro de notificaciones que existe en el backend es
`POST /api/notificaciones/registro`; no se implementó la ruta contractual
`POST /api/dispositivos`.

## Cambios de campos acordados con el backend

(Vacío. Cada vez que Carlos confirme o cambie algo, una línea: fecha, # de ruta, qué cambió.)
