# Cierre de los 22 requisitos críticos – Proyecto 2026 grupo 4

Fecha de corte: 27/10/2026. Documento de cierre de la integración; complementa a
[`estado-backend-grupo4.md`](estado-backend-grupo4.md) (inventario detallado, parte histórico).
Todo lo que figura como verificado salió de ejecuciones reales citadas; lo demás está marcado
**no verificado**.

> **Nota del 30/10/2026:** el sondeo de RF-21 pasó de 3 s a 15 s en el PR #43. Los valores de 3 s de este documento corresponden al corte del 27/10 (HEAD 25405b4), y la latencia medida de ~1,8 s se obtuvo con 3 s.

## 1. Resumen ejecutivo

- **Arquitectura**: backend REST (Java 25, Spring Boot 4.1.1, JDBC `JdbcTemplate`, PostgreSQL 17,
  JWT HS256 + refresh opaco rotativo) y frontend Flutter web (Riverpod, go_router, dio).
  Zona horaria de negocio `America/Montevideo`.
- **Rama de integración**: `integracion/proyecto-2026-avances`, HEAD validado
  **`25405b4e42718c79047ac20320b7dcbaf6415e00`** (merge del PR #39). `main` no se tocó.
- **PR integrados en esta etapa** (en orden, sin conflictos, sin force push): #31 selector de
  médicos, #32 reservas tras inasistencia, #33 RF-24 pases duplicados, #34 RF-35 padrón, #35 RF-08
  disponibilidad, #36 escenarios RF-24, #38 RF-40 histórico (`18f6538`), #39 RF-21 pantalla del
  médico (`0e63be3`). Antes: #30 RF-02/correo.
- **PR abierto**: este de documentación (#37).
- **Estado real del backend**: los 22 críticos tienen endpoints, reglas y pruebas verificadas;
  **22/22 a nivel backend**, con las condiciones de RF-21 (sondeo cada 3 s, no push) y RF-40
  (limitación para fechas sin eventos, sección 4).
- **Estado real del frontend**: Flutter consume auth, primer ingreso, especialidades,
  consultorios, usuarios, turnos semanales (alta, listado, detalle), médicos, disponibilidad,
  reserva con pase, mis consultas y, desde #39, **Mis turnos del médico (RF-21)**. **No hay
  pantallas** para suspensión/rehabilitación de fechas (RF-14/15), aviso de llegada (RF-16),
  agendas del funcionario (RF-18), resultado y pases (RF-23/24), historia clínica (RF-12) ni
  estadísticas reales (RF-39/40/41; `statistics_screen.dart` es una demo). Esas secciones muestran
  «Próximamente».
- **Conclusión**: **22/22 completos a nivel backend** (verificado por pruebas). **No** es 22/22 del
  sistema de punta a punta: faltan las pantallas indicadas, el despliegue no está verificado y
  Resend no está validado (sección 9).

## 2. Matriz de los 22 críticos

Fuente de los nombres y reglas: `docs/analisis/requerimientos.md` (no se modificó).
Estados: COMPLETO, PARCIAL, NO VERIFICADO, AUSENTE. «Estado» = global (backend + frontend).
Tests PG = clases `*IT` contra PostgreSQL 17 (`e2e.yml`).

| RF | Nombre oficial | Endpoint(s) y rol | Tests unidad / HTTP | Tests PG17 | Flutter | Backend | Frontend | Estado |
|---|---|---|---|---|---|---|---|---|
| 01 | Inicio de sesión | `POST /api/auth/login`, `/refresh`, `/logout` | AuthControllerTest, AuthSeguridadTest, AuthServiceTest | AutenticacionIT, CuentasInactivasIT | login/sesión | COMPLETO | COMPLETO | **COMPLETO** |
| 02 | Primer ingreso | `POST /api/auth/primer-ingreso/solicitar`, `/completar` (público) | PrimerIngreso{Controller,Seguridad,Service,MailListener}Test | AutenticacionIT; Mailpit local manual | pantallas solicitar/activar | COMPLETO | COMPLETO | **COMPLETO** (correo remoto Resend no verificado) |
| 08 | Consulta de disponibilidad | `GET /api/disponibilidad` (SOCIO) | AgendaServiceTest, AgendaRepositoryTest, DisponibilidadSeguridadTest | CircuitoConsultasIT, DisponibilidadIT | AvailabilityScreen | COMPLETO | COMPLETO | **COMPLETO** |
| 09 | Agenda de consulta | `POST /api/consultas` (SOCIO) | ConsultaServiceTest, ConsultaRepositoryActivasTest, ConsultaSeguridadTest | CircuitoConsultasIT, ConcurrenciaIT, ReservasTrasInasistenciaIT, PasesRF24IT | AvailabilityScreen, pases | COMPLETO | COMPLETO | **COMPLETO** |
| 11 | Histórico de agendas | `GET /api/consultas`, `/{id}` (SOCIO) | ConsultaHistorialServiceTest | CircuitoConsultasIT, CancelacionConsultaIT | Mis consultas (pendientes y detalle) | COMPLETO | PARCIAL (filtros completos del histórico no verificados) | **PARCIAL** |
| 12 | Consulta de historia clínica | `GET /api/historia-clinica`, `/{id}` (SOCIO) | HistoriaClinica{Service,Repository,Seguridad}Test | HistoriaClinicaIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 13 | Alta de turno semanal | `POST /api/turnos-semanales` (FUNCIONARIO) | TurnoSemanalServiceTest, TurnoSemanalSeguridadTest | CircuitoConsultasIT, MedicoIT | NewWeeklyShiftForm, selector de médicos | COMPLETO | COMPLETO | **COMPLETO** |
| 14 | Suspensión de fechas | `POST /api/turnos/suspensiones[/previsualizar]` (FUNCIONARIO) | TurnoFechasServiceTest, TurnoFechasRepositoryTest | CircuitoConsultasIT, ConcurrenciaIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 15 | Rehabilitación de fechas | `POST /api/turnos/rehabilitaciones` (FUNCIONARIO) | TurnoFechasServiceTest | CircuitoConsultasIT, ConcurrenciaIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 16 | Registro de aviso de llegada | `GET /api/avisos-llegada/consultas-hoy`, `POST /api/avisos-llegada` (FUNCIONARIO) | AvisoLlegada{Service,Repository,Seguridad}Test | LlegadaAgendaMedicoIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 17 | Consulta de turnos | `GET /api/turnos`, `/api/turnos-semanales/{id}` (FUNCIONARIO) | TurnoConsulta{Service,Repository,Seguridad}Test | RolesIT (permisos) | ShiftsScreen | COMPLETO | COMPLETO | **COMPLETO** |
| 18 | Consulta de agendas | `GET /api/agendas` (FUNCIONARIO) | AgendaConsulta{Service,Repository,Seguridad}Test | LlegadaAgendaMedicoIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 21 | Turnos y pacientes de una fecha | `GET /api/medico/turnos`, `/{id}/numeros` (MEDICO) | TurnoMedico{Service,Repository,Seguridad}Test | LlegadaAgendaMedicoIT, **MedicoTurnosTiempoRealIT 7** | DoctorShiftsScreen (`doctor_shifts_test`, 12) | COMPLETO (sondeo de 3 s) | COMPLETO | **COMPLETO** (actualización por sondeo, no push) |
| 23 | Registro del resultado | `POST /api/medico/consultas/{id}/resultado` (MEDICO) | AtencionServiceTest, AtencionRepositoryTest, AtencionSeguridadTest | LlegadaAgendaMedicoIT, ConcurrenciaIT, PasesRF24IT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 24 | Registro de pases | mismo endpoint + `GET /api/socios/me/pases/disponibles` (SOCIO) | AtencionServiceTest | **PasesRF24IT 13**, CancelacionConsultaIT 18, **PasesEscenariosRF24IT 4 (PR #36)** | selección de pase en reserva | COMPLETO | PARCIAL (el socio elige pase; la emisión del médico no tiene pantalla) | **PARCIAL** |
| 29 | Alta de especialidades | `POST /api/especialidades` (ADMIN) | EspecialidadControllerTest, EspecialidadSeguridadTest | RolesIT | pantallas | COMPLETO | COMPLETO | **COMPLETO** |
| 31 | Alta individual de usuarios | `POST /api/usuarios` (ADMIN) | AltaUsuario{Controller,Service,Seguridad}Test | RolesIT, PadronUsuariosIT | NewUserScreen | COMPLETO | COMPLETO | **COMPLETO** |
| 33 | Alta de consultorios | `POST /api/consultorios` (ADMIN) | ConsultorioControllerTest, ConsultorioSeguridadTest | RolesIT | pantallas | COMPLETO | COMPLETO | **COMPLETO** |
| 35 | Consulta de usuarios | `GET /api/usuarios` (ADMIN) | UsuarioServiceTest | **PadronUsuariosIT 9** | UsersScreen, `api_user_repository_test` (contrato `q`, `orden`, `sentido`, `page`, `size`) | COMPLETO | COMPLETO (E2E visual no ejecutado) | **COMPLETO** |
| 39 | Estadísticas por especialidad | `GET /api/estadisticas/especialidades` (ADMIN) | EstadisticaEspecialidad{Service,Repository}Test, EstadisticaSeguridadTest | EstadisticaEspecialidadIT | demo estática | COMPLETO | AUSENTE | **PARCIAL** |
| 40 | Estadísticas por turno | `GET /api/estadisticas/turnos` (ADMIN) | EstadisticaTurno{Service,Repository}Test, EstadisticaSeguridadTest | EstadisticaTurnoIT 9, **EstadisticaTurnoHistoricoIT 12** | — | COMPLETO (interpretación histórica) | AUSENTE | **PARCIAL** (solo backend) |
| 41 | Estadísticas de consultas | `GET /api/estadisticas/consultas` (ADMIN) | EstadisticaConsulta{Service,Repository}Test, EstadisticaSeguridadTest | EstadisticaConsultaIT | — | COMPLETO | AUSENTE | **PARCIAL** |

Recuento (Estado global = backend + frontend): COMPLETO 11 (RF-01, 02, 08, 09, 13, 17, 21, 29, 31,
33, 35); PARCIAL 11, todos por frontend ausente (RF-11 también por filtros del histórico).
**Backend: 22/22 completos. Frontend: 11 completos de 22.** Las clases de test de las columnas se
listan por nombre; no se contó por RF cada caso individual.

### Reglas auditadas en esta etapa

- **RF-08**: la disponibilidad ofrecía números de médicos inhabilitados. Corregido en PR #35
  (`c.habilitada = TRUE`); `DisponibilidadIT` cubre inhabilitado, especialidad, fechas, turno
  suspendido, límite de 30 días y 401/403/400.
- **RF-24** (reglas oficiales, todas con IT): emisión durante la atención; vigencia por defecto de
  90 días y rango 1–365; sin pase duplicado (vigente y sin usar) ni con consulta agendada vigente
  en la especialidad; la AGENDADA de un día terminado no bloquea; consumo al reservar; devolución
  al cancelar conservando id, emisión y vencimiento; sin devolución por inasistencia
  (NO_SE_PRESENTO, NO_ASISTIO, NO_ATENDIDA); atención y pases en una sola transacción; dos
  registros simultáneos crean una sola atención; reintento de una atención guardada → 409
  `CONSULTA_NO_AGENDADA` sin pases nuevos. Defecto corregido en PR #33
  (`AtencionRepository.tienePaseVigenteOConsultaAgendada`). Los escenarios A–D se agregan en PR #36.
- **RF-35**: `q` con `texto` como alias (valores distintos → 400), `orden` (`apellido`,
  `fechaAlta`) y `sentido` en lista blanca (400 si no), `%`/`_` literales, desempate estable por
  `id_cuenta`, una fila por cuenta, varias cuentas por persona, sin contraseñas ni tokens
  (`PadronUsuariosIT`). Flutter envía exactamente esos parámetros (test de contrato
  `api_user_repository_test.dart`).
- **RF-16/18/23**: verificadas por `LlegadaAgendaMedicoIT` (aviso único con hora original,
  conflicto de interés, atención solo con aviso y del día, NO_SE_PRESENTO, concurrencia). Falta
  interfaz en Flutter.

## 3. RF-21: actualización automática

Decisión técnica: **sondeo (polling) cada 3 s** desde Flutter sobre los endpoints existentes. No es
push (ni SSE ni WebSocket): `EventSource` no envía la cabecera `Authorization`, y el sondeo es
compatible con JWT y Railway sin cambios de backend.

- Pantalla `/medico/turnos` (`DoctorShiftsScreen`): fecha, turnos propios, números con paciente
  (nombre, apellido, CI), estado de la consulta, aviso y hora de llegada, filtro de llegada, orden
  por hora o por llegada y sentido.
- `DoctorAgendaController`: `Timer.periodic` de 3 s; no solapa consultas; se pausa con la app
  oculta y reanuda al volver; se cancela al salir o cerrar sesión; conserva filtro y orden; solo
  cambia el estado si los datos cambiaron; un error de red conserva los últimos datos, muestra un
  aviso y reintenta solo.
- Cubre nuevas reservas, cancelaciones, avisos de llegada y resultados porque cada sondeo vuelve a
  leer el estado completo.
- **Latencia medida** (`MedicoTurnosTiempoRealIT`, dos clientes sobre PostgreSQL 17): el
  funcionario registra la llegada y el médico la observa **~1,8 s después** con sondeo de 3 s. El
  máximo teórico es el intervalo (3 s) más el tiempo de la consulta.
- Limitación: no hay notificación inmediata; un cambio puede tardar hasta ~3 s en verse. No se
  probó en navegador real (solo pruebas de widget y de API).

## 4. RF-40: interpretación histórica

Decisión del grupo: **interpretación histórica**. El texto cuenta los números ofrecidos «en las
fechas del período en que la fecha del turno estuvo activa»; antes el SQL tomaba el estado actual
(`turno.estado`). Desde #38 `EstadisticaTurnoRepository` reconstruye el estado de cada fecha con
`turno_evento` (`SUSPENSION`/`REHABILITACION`).

Algoritmo:

- Una fecha cuenta como ofrecida si estaba **activa al cierre de su día** en `America/Montevideo`
  (o al instante actual si el día no terminó).
- El estado es el del último evento con `realizado_en` anterior a ese corte (desempate por
  `id_evento`).
- Sin evento previo, el estado inicial es lo opuesto al primer evento del turno.
- **Limitación**: un turno sin eventos usa `turno.estado`; no se inventan eventos. Un dato
  suspendido por carga directa en la base (sin evento) se interpreta con su estado actual.
- El JSON de respuesta no cambió; las 9 `EstadisticaTurnoIT` previas pasan sin modificación y
  `EstadisticaTurnoHistoricoIT` (12) cubre suspensión posterior, rehabilitación, varios eventos en
  un día, cambio de día, números ocupados, seguridad y casos sin eventos.

Ejemplo del requisito: con estado actual 9/17 = **52,94 %**; con la interpretación histórica (la
fecha suspendida hoy que estuvo activa suma 4 ofrecidos) 9/21 = **42,86 %**. Ese ejemplo
textual no se reprodujo con los datos del IT de marzo; `EstadisticaTurnoHistoricoIT` usa datos
controlados (8 ofrecidos, 3 ocupados) que distinguen ambas interpretaciones.

## 5. Seguridad

- **JWT**: acceso HS256 de 900 s; refresh opaco `v2.` + 32 bytes, hash SHA-256, 7 días, rotativo,
  cookie `httpOnly` (`secure`/`sameSite` por variable).
- **Roles**: SOCIO, FUNCIONARIO, MEDICO, ADMINISTRADOR; rutas por rol en `SecurityConfig`;
  `RolesIT` y los `*SeguridadTest` verifican 401/403. `GET /api/usuarios` solo ADMINISTRADOR;
  `GET /api/medicos` FUNCIONARIO; pases propios solo SOCIO.
- **Cuentas inactivas**: `CuentaVigenteValidator` revisa en cada solicitud que la cuenta exista,
  esté habilitada y conserve el rol (`CuentasInactivasIT` 15). Una cuenta inactiva no activa
  primer ingreso ni puede iniciar sesión.
- **Datos clínicos y propiedad**: el socio se toma siempre del JWT; atención ajena → 404;
  los reportes no exponen pacientes; el médico no atiende su propia consulta (conflicto de interés).
- **Primer ingreso**: token aleatorio, solo su hash en la base, 24 h, un uso, el nuevo invalida
  los previos, respuesta uniforme contra enumeración, sin tokens en logs ni endpoint que
  exponga enlaces.

## 6. Circuitos funcionales

| Circuito | Estado | Evidencia |
|---|---|---|
| Primer ingreso | Funciona con Mailpit local; remoto no verificado | PR #30, `docs/api/railway-correo.md` |
| Reserva | Funciona (con pase y tras inasistencia) | CircuitoConsultasIT, ReservasTrasInasistenciaIT, PasesRF24IT |
| Cancelación | Backend completo; Flutter no consume `cancelar` | CancelacionConsultaIT 18 |
| Pases | Backend completo | PasesRF24IT, PasesEscenariosRF24IT (PR #36) |
| Agenda del funcionario | Solo backend | LlegadaAgendaMedicoIT |
| Aviso de llegada | Solo backend | LlegadaAgendaMedicoIT |
| Atención | Solo backend | LlegadaAgendaMedicoIT, PasesRF24IT |
| Historia clínica | Solo backend | HistoriaClinicaIT |
| Padrón | Backend + Flutter (unitario/contrato) | PadronUsuariosIT, `api_user_repository_test` |
| Estadísticas | Solo backend | EstadisticaEspecialidadIT, EstadisticaTurnoIT, EstadisticaConsultaIT |

Estados derivados `NO_ASISTIO`/`NO_ATENDIDA`: son consultas AGENDADA sin resultado con fecha
anterior a hoy (`America/Montevideo`); `NO_ATENDIDA` si hubo aviso de llegada ese día. No se
persisten ni se corrigen estados históricos.

## 7. Testing

Resultados sobre el **árbol combinado de los PR #30–#39**, idéntico al HEAD `25405b4`
(ejecutados en un worktree limpio antes de publicar):

| Prueba | Resultado |
|---|---|
| Maven `verify` (sin IT) | **419** pruebas, 0 fallos, 0 errores |
| IT PostgreSQL 17 (`*IT`) | **182**, 0 fallos, 0 errores (163 + 12 RF-40 + 7 RF-21) |
| `flutter analyze` | sin problemas |
| `flutter test` | **909** aprobadas (897 + 12 RF-21) |
| `flutter build web --release` | OK |

CI de los PR: #38 Backend, E2E PostgreSQL e Imagen en success (el filtro de rutas no dispara
Frontend); #39 Backend, E2E PostgreSQL, Imagen y Frontend en success. #35: 159/159 IT y #36:
161/161 IT según CI, antes de combinarse. El resultado de los workflows sobre el HEAD publicado
`25405b4` **no se verificó en este documento**; debe consultarse en GitHub Actions. Esquema no se
dispara por filtro de rutas.

Las IT corren con base descartable terminada en `_e2e`/`_test`, `E2E_ALLOW_DESTRUCTIVE=true` y
`mvnw test -Dtest=*IT`; sin esa variable fallan por diseño.

**Concurrencia cubierta**: reservas simultáneas del mismo número y del mismo pase, cancelaciones
dobles, registro simultáneo de una atención, rehabilitación/suspensión, activación de primer ingreso.

**Limitaciones**: no hay E2E visual (navegador); las pruebas Flutter son unitarias y de widgets;
no se ejecutaron los scripts de Drive (contienen `TRUNCATE` de 21 tablas) y la carpeta requiere
login de Google, por lo que no se pudo verificar V2/V3.

## 8. Despliegue

- **Railway**: no verificado, no modificado. No se comprobó qué versión hay desplegada.
- **Resend**: **no validado**; faltan `RESEND_API_KEY`, dominio verificado y acceso a Railway.
  Configuración y responsable en `docs/api/railway-correo.md`.
- **Mailpit** (local): correo de primer ingreso recibido y activación completada (PR #30).
- **Frontend desplegado**: no verificado; debe confirmarse que usa el build con la reserva con pase.

## 9. Pendientes

**Funcionalidades (frontend)**: pantallas de RF-14/15, 16, 18, 23/24 (emisión de pases), 12,
39/40/41 y cancelación de consultas del socio; histórico RF-11 con todos sus filtros.

**Integración**: fusionar este PR; luego verificar los workflows del HEAD final.

**Infraestructura**: Railway/Resend (sección 8); datos de prueba de Drive (acceso).

**Decisiones del grupo**: alcance de entrega si las pantallas no llegan; si el sondeo de 3 s de
RF-21 se considera suficiente como «tiempo real» o se exige push.

**Para la demostración**: levantar PostgreSQL 17 efímero con datos ficticios (no usar scripts de
Drive sobre bases compartidas), backend con `MAIL_PROVIDER=smtp` y Mailpit, `flutter build web`,
y limitar el recorrido a los circuitos con pantalla (primer ingreso, login, reserva con pase,
turnos, padrón, especialidades/consultorios); lo demás mostrarlo por HTTP.
