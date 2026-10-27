# Cierre de los 22 requisitos críticos – Proyecto 2026 grupo 4

Fecha de corte: 27/10/2026. Documento de cierre de la integración; complementa a
[`estado-backend-grupo4.md`](estado-backend-grupo4.md) (inventario detallado, parte histórico).
Todo lo que figura como verificado salió de ejecuciones reales citadas; lo demás está marcado
**no verificado**.

## 1. Resumen ejecutivo

- **Arquitectura**: backend REST (Java 25, Spring Boot 4.1.1, JDBC `JdbcTemplate`, PostgreSQL 17,
  JWT HS256 + refresh opaco rotativo) y frontend Flutter web (Riverpod, go_router, dio).
  Zona horaria de negocio `America/Montevideo`.
- **Rama de integración**: `integracion/proyecto-2026-avances`, HEAD verificado
  **`4612f0d25b683de47ff7099320e700bac0d9b509`** (merge del PR #34). `main` no se tocó.
- **PR integrados en esta etapa** (en orden, sin conflictos, sin force push): #31 selector de
  médicos (`5ed6448`), #32 reservas tras inasistencia (`d29edc0`), #33 RF-24 pases duplicados
  (`5f41c93`), #34 RF-35 padrón (`4612f0d`). Antes: #30 RF-02/correo.
- **PR abiertos, no fusionados**: #35 RF-08 disponibilidad solo con médicos habilitados
  (`6103d03`), #36 pruebas de cierre de RF-24 (`880e4f6`), y el PR de esta documentación.
- **Estado real del backend**: los 22 críticos tienen endpoints, reglas y pruebas. 20 están
  completos; **RF-21** (falta «tiempo real») y **RF-40** (interpretación histórica pendiente de
  decisión del grupo) quedan **parciales**. RF-08 está completo solo cuando se fusione el PR #35.
- **Estado real del frontend**: Flutter consume auth, primer ingreso, especialidades,
  consultorios, usuarios, turnos semanales (alta, listado, detalle), médicos, disponibilidad,
  reserva con pase, mis consultas. **No hay pantallas** para suspensión/rehabilitación de fechas
  (RF-14/15), aviso de llegada (RF-16), agendas del funcionario (RF-18), turnos y pacientes del
  médico (RF-21), resultado y pases (RF-23/24), historia clínica (RF-12) ni estadísticas reales
  (RF-39/40/41; `statistics_screen.dart` es una demo). Esas secciones muestran «Próximamente».
- **Conclusión**: no se declara 22/22. El backend cubre los 22 con las dos excepciones
  indicadas; la entrega completa depende de las pantallas ausentes y de dos decisiones
  (sección 9).

## 2. Matriz de los 22 críticos

Fuente de los nombres y reglas: `docs/analisis/requerimientos.md` (no se modificó).
Estados: COMPLETO, PARCIAL, NO VERIFICADO, AUSENTE. «Estado» = global (backend + frontend).
Tests PG = clases `*IT` contra PostgreSQL 17 (`e2e.yml`).

| RF | Nombre oficial | Endpoint(s) y rol | Tests unidad / HTTP | Tests PG17 | Flutter | Backend | Frontend | Estado |
|---|---|---|---|---|---|---|---|---|
| 01 | Inicio de sesión | `POST /api/auth/login`, `/refresh`, `/logout` | AuthControllerTest, AuthSeguridadTest, AuthServiceTest | AutenticacionIT, CuentasInactivasIT | login/sesión | COMPLETO | COMPLETO | **COMPLETO** |
| 02 | Primer ingreso | `POST /api/auth/primer-ingreso/solicitar`, `/completar` (público) | PrimerIngreso{Controller,Seguridad,Service,MailListener}Test | AutenticacionIT; Mailpit local manual | pantallas solicitar/activar | COMPLETO | COMPLETO | **COMPLETO** (correo remoto Resend no verificado) |
| 08 | Consulta de disponibilidad | `GET /api/disponibilidad` (SOCIO) | AgendaServiceTest, AgendaRepositoryTest, DisponibilidadSeguridadTest | CircuitoConsultasIT; **DisponibilidadIT (PR #35)** | AvailabilityScreen | COMPLETO tras PR #35 | COMPLETO | **COMPLETO al fusionar #35** |
| 09 | Agenda de consulta | `POST /api/consultas` (SOCIO) | ConsultaServiceTest, ConsultaRepositoryActivasTest, ConsultaSeguridadTest | CircuitoConsultasIT, ConcurrenciaIT, ReservasTrasInasistenciaIT, PasesRF24IT | AvailabilityScreen, pases | COMPLETO | COMPLETO | **COMPLETO** |
| 11 | Histórico de agendas | `GET /api/consultas`, `/{id}` (SOCIO) | ConsultaHistorialServiceTest | CircuitoConsultasIT, CancelacionConsultaIT | Mis consultas (pendientes y detalle) | COMPLETO | PARCIAL (filtros completos del histórico no verificados) | **PARCIAL** |
| 12 | Consulta de historia clínica | `GET /api/historia-clinica`, `/{id}` (SOCIO) | HistoriaClinica{Service,Repository,Seguridad}Test | HistoriaClinicaIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 13 | Alta de turno semanal | `POST /api/turnos-semanales` (FUNCIONARIO) | TurnoSemanalServiceTest, TurnoSemanalSeguridadTest | CircuitoConsultasIT, MedicoIT | NewWeeklyShiftForm, selector de médicos | COMPLETO | COMPLETO | **COMPLETO** |
| 14 | Suspensión de fechas | `POST /api/turnos/suspensiones[/previsualizar]` (FUNCIONARIO) | TurnoFechasServiceTest, TurnoFechasRepositoryTest | CircuitoConsultasIT, ConcurrenciaIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 15 | Rehabilitación de fechas | `POST /api/turnos/rehabilitaciones` (FUNCIONARIO) | TurnoFechasServiceTest | CircuitoConsultasIT, ConcurrenciaIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 16 | Registro de aviso de llegada | `GET /api/avisos-llegada/consultas-hoy`, `POST /api/avisos-llegada` (FUNCIONARIO) | AvisoLlegada{Service,Repository,Seguridad}Test | LlegadaAgendaMedicoIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 17 | Consulta de turnos | `GET /api/turnos`, `/api/turnos-semanales/{id}` (FUNCIONARIO) | TurnoConsulta{Service,Repository,Seguridad}Test | RolesIT (permisos) | ShiftsScreen | COMPLETO | COMPLETO | **COMPLETO** |
| 18 | Consulta de agendas | `GET /api/agendas` (FUNCIONARIO) | AgendaConsulta{Service,Repository,Seguridad}Test | LlegadaAgendaMedicoIT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 21 | Turnos y pacientes de una fecha | `GET /api/medico/turnos`, `/{id}/numeros` (MEDICO) | TurnoMedico{Service,Repository,Seguridad}Test | LlegadaAgendaMedicoIT | — | **PARCIAL** (sin tiempo real) | AUSENTE | **PARCIAL** |
| 23 | Registro del resultado | `POST /api/medico/consultas/{id}/resultado` (MEDICO) | AtencionServiceTest, AtencionRepositoryTest, AtencionSeguridadTest | LlegadaAgendaMedicoIT, ConcurrenciaIT, PasesRF24IT | — | COMPLETO | AUSENTE | **PARCIAL** |
| 24 | Registro de pases | mismo endpoint + `GET /api/socios/me/pases/disponibles` (SOCIO) | AtencionServiceTest | **PasesRF24IT 13**, CancelacionConsultaIT 18, **PasesEscenariosRF24IT 4 (PR #36)** | selección de pase en reserva | COMPLETO | PARCIAL (el socio elige pase; la emisión del médico no tiene pantalla) | **PARCIAL** |
| 29 | Alta de especialidades | `POST /api/especialidades` (ADMIN) | EspecialidadControllerTest, EspecialidadSeguridadTest | RolesIT | pantallas | COMPLETO | COMPLETO | **COMPLETO** |
| 31 | Alta individual de usuarios | `POST /api/usuarios` (ADMIN) | AltaUsuario{Controller,Service,Seguridad}Test | RolesIT, PadronUsuariosIT | NewUserScreen | COMPLETO | COMPLETO | **COMPLETO** |
| 33 | Alta de consultorios | `POST /api/consultorios` (ADMIN) | ConsultorioControllerTest, ConsultorioSeguridadTest | RolesIT | pantallas | COMPLETO | COMPLETO | **COMPLETO** |
| 35 | Consulta de usuarios | `GET /api/usuarios` (ADMIN) | UsuarioServiceTest | **PadronUsuariosIT 9** | UsersScreen, `api_user_repository_test` (contrato `q`, `orden`, `sentido`, `page`, `size`) | COMPLETO | COMPLETO (E2E visual no ejecutado) | **COMPLETO** |
| 39 | Estadísticas por especialidad | `GET /api/estadisticas/especialidades` (ADMIN) | EstadisticaEspecialidad{Service,Repository}Test, EstadisticaSeguridadTest | EstadisticaEspecialidadIT | demo estática | COMPLETO | AUSENTE | **PARCIAL** |
| 40 | Estadísticas por turno | `GET /api/estadisticas/turnos` (ADMIN) | EstadisticaTurno{Service,Repository}Test, EstadisticaSeguridadTest | EstadisticaTurnoIT | — | **PARCIAL** (decisión pendiente) | AUSENTE | **PARCIAL** |
| 41 | Estadísticas de consultas | `GET /api/estadisticas/consultas` (ADMIN) | EstadisticaConsulta{Service,Repository}Test, EstadisticaSeguridadTest | EstadisticaConsultaIT | — | COMPLETO | AUSENTE | **PARCIAL** |

Recuento: COMPLETO 9 (RF-01, 02, 09, 13, 17, 29, 31, 33, 35) + RF-08 al fusionar #35 = 10;
PARCIAL 12. Backend: 20 completos, 2 parciales (RF-21, RF-40). Las clases de test de las
columnas se listan por nombre; no se contó por RF cada caso individual.

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

## 3. RF-21: actualización en tiempo real

Búsqueda en backend (`SseEmitter`, `text/event-stream`, WebSocket) y frontend (`Timer.periodic`,
`Stream.periodic`, `WebSocket`, `EventSource`): **sin resultados**. No existe ningún mecanismo,
ni pantalla del médico. Los endpoints responden bajo demanda, de modo que el médico solo vería
cambios recargando. **RF-21 queda PARCIAL.**

Opciones (decisión del grupo pendiente; no se implementó para no simular cumplimiento):

| Opción | Ventaja | Riesgo |
|---|---|---|
| Polling de la pantalla cada 10–15 s (recomendada) | Sin cambios de backend, compatible con JWT y con Railway, latencia ≤ intervalo | Más consultas; hay que pausar con la pestaña oculta |
| SSE | Latencia baja | `EventSource` no envía cabecera `Authorization`; exige token por URL o cliente propio |
| WebSocket | Bidireccional | Más infraestructura y seguridad; excesivo para una lista |

Debe incluir nuevas reservas, cancelaciones, avisos de llegada y cambios de estado. Frecuencia
y latencia se documentarán al elegir la opción. Primero hay que construir la pantalla.

## 4. RF-40: brecha histórica

El texto exige contar los números ofrecidos «en las fechas del período en que la fecha del turno
estuvo activa». El SQL actual (`EstadisticaTurnoRepository`) toma `turno.estado = 'ACTIVO'`
(estado actual) y no consulta `turno_evento` (historial de `SUSPENSION`/`REHABILITACION`).

| Escenario | Resultado actual | Verificado por |
|---|---|---|
| 1. Fecha activa durante todo el período | Entra con sus números ofrecidos y ocupados | `EstadisticaTurnoIT` fechas A, B |
| 2. Fecha suspendida y luego rehabilitada | Vuelve a ACTIVO; entra completa; lo cancelado por la suspensión queda libre (ejemplo: 4 ofrecidos, 1 ocupado) | `EstadisticaTurnoIT` fecha D |
| 3. Fecha suspendida **hoy** que estuvo activa antes | Se excluye (ejemplo: fecha C, 4 números) | `EstadisticaTurnoIT` fecha C |

Interpretaciones:

- **A (actual)**: «activa» = estado vigente de la fecha. Ejemplo del IT de marzo: 17 ofrecidos,
  9 ocupados → **52,94 %**.
- **B**: «estuvo activa» = la fecha estuvo activa en algún momento del período, aunque hoy esté
  suspendida. La fecha C aporta 4 ofrecidos y 0 ocupados (sus consultas quedaron
  `CANCELADA_INSTITUCION`): 21 ofrecidos, 9 ocupados → **42,86 %**.

Con B toda fecha creada contaría (nace activa), y la condición casi no filtra; además penaliza al
turno por una suspensión institucional. **Recomendación: A**, documentada y probada (la
`turno_evento` sigue siendo auditoría). **Decisión pendiente del grupo**; hasta entonces RF-40 es
PARCIAL. No se cambió código.

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

Resultados sobre el **árbol combinado de los PR #31–#34**, idéntico al HEAD `4612f0d`
(árbol `a5a4c0227aec247df10472f43dbd853834dfe1fa`):

| Prueba | Resultado |
|---|---|
| Maven `verify` (sin IT) | **419** pruebas, 0 fallos, 0 errores, 0 omitidas |
| IT PostgreSQL 17 (`*IT`) | **157**, 0 fallos, 0 errores, 0 omitidas |
| 5 clases de contexto completo | BUILD SUCCESS (conteo no desagregado) |
| `flutter analyze` | sin problemas |
| `flutter test` | **897** aprobadas |
| `flutter build web --release` | OK |

Workflows en el push a avances: `4612f0d` Backend, E2E PostgreSQL e Imagen en **success**
(runs 40582023179, 40582022534, 40582022526). Frontend y Esquema no se disparan por filtro de rutas.

| PR | Commit | Backend | E2E PG | Imagen | Notas |
|---|---|---|---|---|---|
| #35 RF-08 | `6103d03` | success | success | success | 159/159 IT según CI |
| #36 RF-24 | `880e4f6` | success | success | pendiente al escribir | +4 IT |

Tras fusionar #35 y #36 el total esperado de IT es 163 (157 + 2 + 4); **no se afirma hasta ver el
run del HEAD final**. Las IT corren con base descartable terminada en `_e2e`/`_test`,
`E2E_ALLOW_DESTRUCTIVE=true` y `mvnw test -Dtest=*IT`; sin esa variable fallan por diseño.

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

**Funcionalidades (frontend)**: pantallas de RF-14/15, 16, 18, 21, 23/24 (emisión de pases),
12, 39/40/41 y cancelación de consultas del socio; histórico RF-11 con todos sus filtros.

**Integración**: fusionar #35, #36 y este PR (autorización del equipo); luego verificar los
workflows del HEAD final.

**Infraestructura**: Railway/Resend (sección 8); datos de prueba de Drive (acceso).

**Decisiones del grupo**: (1) RF-21 mecanismo de tiempo real; (2) RF-40 interpretación A o B;
(3) alcance de entrega si las pantallas no llegan.

**Para la demostración**: levantar PostgreSQL 17 efímero con datos ficticios (no usar scripts de
Drive sobre bases compartidas), backend con `MAIL_PROVIDER=smtp` y Mailpit, `flutter build web`,
y limitar el recorrido a los circuitos con pantalla (primer ingreso, login, reserva con pase,
turnos, padrón, especialidades/consultorios); lo demás mostrarlo por HTTP.
