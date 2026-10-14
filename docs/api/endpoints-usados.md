# Registro de endpoints: propuestos y usados por el frontend

Lugar en el repo: `docs/api/endpoints-usados.md`. Se mantiene a medida que avanza el frontend.

**Estado de la ruta**
- PROPUESTA: la propuso el frontend a partir del Diseño 2.3. El backend no la confirmó.
- CONFIRMADA: el backend la implementó o la aceptó tal cual.
- CAMBIADA: el backend usa otra. Se anota la ruta nueva y qué campos cambiaron.

**Usada por el front**: `-` si todavía no hay código que la llame; si no, rama o PR y fecha. Para avisarle a quien haga el backend, filtrá las filas con una rama anotada y estado PROPUESTA.

Las rutas viven todas en `frontend/lib/core/network/api_routes.dart`. Cambiar una ruta es cambiar una línea ahí, más la fila de acá.

## Semana 1

| # | Método y ruta | Roles | RF | Pantalla del front | Estado | Usada por el front |
|---|---|---|---|---|---|---|
| 1 | `POST /api/auth/login` | público | 01 | Login | PROPUESTA | - |
| 2 | `POST /api/auth/refresh` | público (cookie) | 01 | Renovación de sesión | PROPUESTA | - |
| 3 | `POST /api/auth/logout` | autenticado | 03 | Cerrar sesión | PROPUESTA | - |
| 4 | `POST /api/auth/primer-ingreso/solicitar` | público | 02 | Pedir activación | PROPUESTA | - |
| 5 | `POST /api/auth/primer-ingreso/completar` | público (token) | 02 | Activar cuenta | PROPUESTA | - |
| 6 | `GET /api/especialidades` | autenticado | 29 | Formularios y listado | PROPUESTA | - |
| 7 | `POST /api/especialidades` | ADMINISTRADOR | 29 | Alta de especialidad | PROPUESTA | - |
| 8 | `GET /api/consultorios` | autenticado | 33 | Formularios y listado | PROPUESTA | - |
| 9 | `POST /api/consultorios` | ADMINISTRADOR | 33 | Alta de consultorio | PROPUESTA | - |
| 10 | `GET /api/medicos?especialidadId=` | autenticado | 13, 08 | Selector de médico | PROPUESTA | - |
| 11 | `POST /api/usuarios` | ADMINISTRADOR | 31 | Alta de usuario | PROPUESTA | - |
| 12 | `GET /api/usuarios` | ADMINISTRADOR | 35 | Consulta de usuarios | PROPUESTA | - |
| 13 | `POST /api/turnos-semanales` | FUNCIONARIO | 13 | Alta de turno semanal | PROPUESTA | - |
| 14 | `GET /api/turnos-semanales/{id}` | FUNCIONARIO | 17 | Detalle de configuración | PROPUESTA | - |
| 15 | `GET /api/turnos` | FUNCIONARIO | 17 | Consulta de turnos | PROPUESTA | - |
| 16 | `GET /api/disponibilidad` | SOCIO | 08 | Disponibilidad | PROPUESTA | - |
| 17 | `POST /api/consultas` | SOCIO | 09 | Confirmar agenda | PROPUESTA | - |

## Semana 2 y adelantos

| # | Método y ruta | Roles | RF | Pantalla del front | Estado | Usada por el front |
|---|---|---|---|---|---|---|
| 18 | `GET /api/consultas` | SOCIO | 11 | Mis consultas | PROPUESTA | - |
| 19 | `GET /api/consultas/{id}` | SOCIO | 11 | Detalle de consulta | PROPUESTA | - |
| 20 | `POST /api/consultas/{id}/cancelar` | SOCIO | 10 | Cancelar consulta | PROPUESTA | - |
| 21 | `GET /api/historia-clinica` | SOCIO | 12 | Historia clínica | PROPUESTA | - |
| 22 | `GET /api/historia-clinica/{idAtencion}` | SOCIO | 12 | Detalle de atención | PROPUESTA | - |
| 23 | `POST /api/turnos/suspensiones/previsualizar` | FUNCIONARIO | 14 | Confirmación previa | PROPUESTA | - |
| 24 | `POST /api/turnos/suspensiones` | FUNCIONARIO | 14 | Suspender fechas | PROPUESTA | - |
| 25 | `POST /api/turnos/rehabilitaciones` | FUNCIONARIO | 15 | Rehabilitar fechas | PROPUESTA | - |
| 26 | `GET /api/avisos-llegada/consultas-hoy?ci=` | FUNCIONARIO | 16 | Buscar socio | PROPUESTA | - |
| 27 | `POST /api/avisos-llegada` | FUNCIONARIO | 16 | Registrar llegada | PROPUESTA | - |
| 28 | `GET /api/agendas` | FUNCIONARIO | 18 | Consulta de agendas | PROPUESTA | - |
| 29 | `GET /api/medico/turnos?fecha=` | MEDICO | 21 | Mis turnos | PROPUESTA | - |
| 30 | `GET /api/medico/turnos/{id}/numeros` | MEDICO | 21 | Pacientes del turno | PROPUESTA | - |
| 31 | `POST /api/medico/consultas/{id}/resultado` | MEDICO | 23, 24 | Registrar atención y pases | PROPUESTA | - |
| 32 | `GET /api/notificaciones` | SOCIO | RNF-24 | Lista de notificaciones | PROPUESTA | - |
| 33 | `POST /api/dispositivos` | SOCIO | RNF-24 | Registro de token push | PROPUESTA | - |
| 34 | `GET /api/estadisticas/especialidades` | ADMINISTRADOR | 39 | Estadísticas | PROPUESTA | - |
| 35 | `GET /api/estadisticas/turnos` | ADMINISTRADOR | 40 | Estadísticas | PROPUESTA | - |
| 36 | `GET /api/estadisticas/consultas` | ADMINISTRADOR | 41 | Estadísticas | PROPUESTA | - |

## Rutas de la prueba de concepto que el frontend llama hoy

Dejan de usarse cuando se migra cada pantalla. Cuando una deje de usarse se tacha acá y se anota la rama.

| Ruta actual | La reemplaza | Estado |
|---|---|---|
| `POST /api/auth/login` con `{cedula, clave}` | #1, con `{ci, password, acceso}` | cambia el cuerpo |
| `POST /api/auth/refresh`, `POST /api/auth/logout` | #2 y #3 | sin cambios previstos |
| `GET /api/profesionales` | #10 | pendiente |
| `GET /api/profesionales/{id}/horarios` | #16 | pendiente |
| `POST /api/reservas` | #17 | pendiente |
| `GET /api/mis-reservas` | #18 | pendiente |
| `PATCH /api/reservas/{id}/cancelacion` | #20 | pendiente |
| `POST /api/notificaciones/registro` | #33 | pendiente |

## Cambios de campos acordados con el backend

(Vacío. Cada vez que Carlos confirme o cambie algo, una línea: fecha, # de ruta, qué cambió.)
