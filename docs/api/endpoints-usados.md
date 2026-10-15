# Registro de endpoints: propuestos y usados por el frontend

Lugar en el repo: `docs/api/endpoints-usados.md`. Se mantiene a medida que avanza el frontend.

**Estado de la ruta**
- PROPUESTA: la propuso el frontend a partir del Diseño 2.3. El backend no la confirmó.
- CONFIRMADA: el backend la implementó o la aceptó tal cual.
- CAMBIADA: el backend usa otra. Se anota la ruta nueva y qué campos cambiaron.

**Usada por el front**: `-` si todavía no hay código que la llame; si no, rama o PR y fecha. Para avisarle a quien haga el backend, filtrá las filas con una rama anotada y estado PROPUESTA.

**Campos y errores**: cada fila enlaza a su sección de `docs/api/contrato-v1.md` (rama `docs/contrato-api`, 14/10/2026), donde están los parámetros, el JSON de ejemplo, los errores y los roles. Todas las filas siguen en PROPUESTA hasta que el backend confirme. Lo que el backend debe responder antes de implementar está en la sección 9 del contrato (Preguntas abiertas).

Las rutas viven todas en `frontend/lib/core/network/api_routes.dart`. Cambiar una ruta es cambiar una línea ahí, más la fila de acá.

## Semana 1

| # | Método y ruta | Roles | RF | Pantalla del front | Estado | Usada por el front | Campos y errores |
|---|---|---|---|---|---|---|---|
| 1 | `POST /api/auth/login` | público | 01 | Login | PROPUESTA | feat/front-acceso-roles 14/10/2026 | [contrato #1](contrato-v1.md#e01) |
| 2 | `POST /api/auth/refresh` | público (cookie) | 01 | Renovación de sesión | PROPUESTA | feat/front-acceso-roles 14/10/2026 | [contrato #2](contrato-v1.md#e02) |
| 3 | `POST /api/auth/logout` | autenticado | 03 | Cerrar sesión | PROPUESTA | feat/front-acceso-roles 14/10/2026 | [contrato #3](contrato-v1.md#e03) |
| 4 | `POST /api/auth/primer-ingreso/solicitar` | público | 02 | Pedir activación | PROPUESTA | feat/front-acceso-roles 14/10/2026 | [contrato #4](contrato-v1.md#e04) |
| 5 | `POST /api/auth/primer-ingreso/completar` | público (token) | 02 | Activar cuenta | PROPUESTA | feat/front-acceso-roles 14/10/2026 | [contrato #5](contrato-v1.md#e05) |
| 6 | `GET /api/especialidades` | autenticado | 29 | Formularios y listado | PROPUESTA | - | [contrato #6](contrato-v1.md#e06) |
| 7 | `POST /api/especialidades` | ADMINISTRADOR | 29 | Alta de especialidad | PROPUESTA | - | [contrato #7](contrato-v1.md#e07) |
| 8 | `GET /api/consultorios` | autenticado | 33 | Formularios y listado | PROPUESTA | - | [contrato #8](contrato-v1.md#e08) |
| 9 | `POST /api/consultorios` | ADMINISTRADOR | 33 | Alta de consultorio | PROPUESTA | - | [contrato #9](contrato-v1.md#e09) |
| 10 | `GET /api/medicos?especialidadId=` | autenticado | 13, 08 | Selector de médico | PROPUESTA | - | [contrato #10](contrato-v1.md#e10) |
| 11 | `POST /api/usuarios` | ADMINISTRADOR | 31 | Alta de usuario | PROPUESTA | - | [contrato #11](contrato-v1.md#e11) |
| 12 | `GET /api/usuarios` | ADMINISTRADOR | 35 | Consulta de usuarios | PROPUESTA | - | [contrato #12](contrato-v1.md#e12) |
| 13 | `POST /api/turnos-semanales` | FUNCIONARIO | 13 | Alta de turno semanal | PROPUESTA | - | [contrato #13](contrato-v1.md#e13) |
| 14 | `GET /api/turnos-semanales/{id}` | FUNCIONARIO | 17 | Detalle de configuración | PROPUESTA | - | [contrato #14](contrato-v1.md#e14) |
| 15 | `GET /api/turnos` | FUNCIONARIO | 17 | Consulta de turnos | PROPUESTA | - | [contrato #15](contrato-v1.md#e15) |
| 16 | `GET /api/disponibilidad` | SOCIO | 08 | Disponibilidad | PROPUESTA | - | [contrato #16](contrato-v1.md#e16) |
| 17 | `POST /api/consultas` | SOCIO | 09 | Confirmar agenda | PROPUESTA | - | [contrato #17](contrato-v1.md#e17) |

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
| 26 | `GET /api/avisos-llegada/consultas-hoy?ci=` | FUNCIONARIO | 16 | Buscar socio | PROPUESTA | - | [contrato #26](contrato-v1.md#e26) |
| 27 | `POST /api/avisos-llegada` | FUNCIONARIO | 16 | Registrar llegada | PROPUESTA | - | [contrato #27](contrato-v1.md#e27) |
| 28 | `GET /api/agendas` | FUNCIONARIO | 18 | Consulta de agendas | PROPUESTA | - | [contrato #28](contrato-v1.md#e28) |
| 29 | `GET /api/medico/turnos?fecha=` | MEDICO | 21 | Mis turnos | PROPUESTA | - | [contrato #29](contrato-v1.md#e29) |
| 30 | `GET /api/medico/turnos/{id}/numeros` | MEDICO | 21 | Pacientes del turno | PROPUESTA | - | [contrato #30](contrato-v1.md#e30) |
| 31 | `POST /api/medico/consultas/{id}/resultado` | MEDICO | 23, 24 | Registrar atención y pases | PROPUESTA | - | [contrato #31](contrato-v1.md#e31) |
| 32 | `GET /api/notificaciones` | SOCIO | RNF-24 | Lista de notificaciones | PROPUESTA | - | [contrato #32](contrato-v1.md#e32) |
| 33 | `POST /api/dispositivos` | SOCIO | RNF-24 | Registro de token push | PROPUESTA | - | [contrato #33](contrato-v1.md#e33) |
| 34 | `GET /api/estadisticas/especialidades` | ADMINISTRADOR | 39 | Estadísticas | PROPUESTA | - | [contrato #34](contrato-v1.md#e34) |
| 35 | `GET /api/estadisticas/turnos` | ADMINISTRADOR | 40 | Estadísticas | PROPUESTA | - | [contrato #35](contrato-v1.md#e35) |
| 36 | `GET /api/estadisticas/consultas` | ADMINISTRADOR | 41 | Estadísticas | PROPUESTA | - | [contrato #36](contrato-v1.md#e36) |

## Rutas de la prueba de concepto que el frontend llama hoy

Dejan de usarse cuando se migra cada pantalla. Cuando una deje de usarse se tacha acá y se anota la rama.

| Ruta actual | La reemplaza | Estado |
|---|---|---|
| `POST /api/auth/login` con `{cedula, clave}` | #1, con `{ci, password, acceso}` | migrada en feat/front-acceso-roles (14/10/2026) |
| `POST /api/auth/refresh`, `POST /api/auth/logout` | #2 y #3 | sin cambios; el cliente lee `role` como `UserRole` (feat/front-acceso-roles, 14/10/2026) |
| `GET /api/profesionales` | #10 | pendiente |
| `GET /api/profesionales/{id}/horarios` | #16 | pendiente |
| `POST /api/reservas` | #17, con `{numeroId, paseId?}` | pendiente |
| `GET /api/mis-reservas` | #18 | pendiente |
| `PATCH /api/reservas/{id}/cancelacion` | #20 | pendiente |
| `POST /api/notificaciones/registro` | #33, con `{token}` | pendiente |

## Cambios de campos acordados con el backend

(Vacío. Cada vez que Carlos confirme o cambie algo, una línea: fecha, # de ruta, qué cambió.)
