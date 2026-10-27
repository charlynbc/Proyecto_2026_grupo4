# Estado del backend – Proyecto 2026 grupo 4

Informe elaborado por lectura del código del worktree `Proyecto_2026_grupo4-rf39`
(rama `feat/rf-39-estadisticas-especialidad`, HEAD `528201d`, padre `28b33a6`).
No se ejecutó Maven ni ninguna prueba al escribirlo: los números de pruebas
salen de contar anotaciones `@Test`/`@ParameterizedTest`, del `pom.xml` y de los
workflows, y se contrastan con los datos confirmados por el equipo.
Lo que no se pudo verificar se marca como **no verificado**.

## 1. Resumen ejecutivo

- Backend REST en Java 25 / Spring Boot 4.1.1 con JDBC (`JdbcTemplate`) y PostgreSQL 17.
- De los 22 RF críticos, con el criterio de la leyenda de la sección 5:
  **20 completos (RF-12 completo en su rama `feat/cierre-historia-clinica`, sin integrar) y 2 parciales (RF-24, RF-35)**; RF-40 completo con la brecha funcional histórica registrada.
- RF-39 (PR #24) y RF-40 (PR #25) están **integrados en `avances`**, igual que la corrección transversal de seguridad JWT (PR #26, avances en `a55dbda`). RF-41 (estadísticas de consultas) está **implementado en la rama `feat/rf-41-estadisticas-consultas`** (`GET /api/estadisticas/consultas`), aún no integrado; el estado de CI se registra en su PR.
- **Bloque B (RF-12, rama `feat/cierre-historia-clinica`)**: RF-10 ya está **integrado** (PR #28, `2fde720`, 100 IT aprobadas). RF-12 pasa a completo en la rama: corrige la fecha de atención (zona `America/Montevideo`), el escape de `%`/`_` en `texto`, el alias `orden=fecha` y el 400 `VALIDACION` para ids no numéricos; añade `HistoriaClinicaIT`. Suite Maven local: **415** pruebas, 0 fallos. Paginación: se mantiene la lista sin paginar (decisión en contrato #21). RF-24 sigue **parcial**.
- Con RF-41 la suite Maven local es de **395** pruebas, 0 fallos (+ `EstadisticaConsultaServiceTest` 8, `EstadisticaConsultaRepositoryTest` 1, `EstadisticaSeguridadTest` +5, más las 11 de `CuentaVigenteValidatorTest` ya integradas). `EstadisticaConsultaIT` (13) solo corre en `e2e.yml` contra PostgreSQL 17 efímero; su resultado se registra en el PR.
- RF-40, antes: suite Maven de 358 a **370** pruebas y las IT de 45 a **54**, confirmado en GitHub Actions (PR #25, commit `ca1af34`, PostgreSQL 17.11 efímero): 54 ejecutadas, 54 aprobadas, 0 fallidas, 0 errores, 0 omitidas (`EstadisticaTurnoIT` 9/9).
- Suite Maven (`mvnw verify`) en `avances`: **343 pruebas**, 0 fallos (el «686» fue un error de conteo duplicado). Con RF-39: 343 + 15 = **358**, confirmado en GitHub Actions (PR #24, commit 528201d): 358 aprobadas, 0 fallos, 0 errores, 0 omitidas. El «686» no corresponde a ninguna salida real de Maven.
- Las pruebas `*IT` no corren con `mvnw verify`; corren en `.github/workflows/e2e.yml` contra PostgreSQL 17 efímero: **39 IT aprobadas** en `avances` antes de RF-39 (+ 18 pruebas de contexto). `EstadisticaEspecialidadIT` (6) **aprobó en CI** (PostgreSQL 17.11 efímero): 45 IT ejecutadas, 45 aprobadas, 0 fallidas, 0 omitidas (AutenticacionIT 19, CircuitoConsultasIT 4, ConcurrenciaIT 5, EstadisticaEspecialidadIT 6, LlegadaAgendaMedicoIT 6, RolesIT 5).
- Railway: **no verificado en esta sesión**. El repo documenta la configuración prevista, no un despliegue realizado.
- Discrepancias principales: ver secciones 5, 14 y 17.

## 2. Tecnologías

Fuente: `backend/api/pom.xml`, `application.properties`.

| Elemento | Valor |
|---|---|
| Java / Spring Boot | 25 / `spring-boot-starter-parent` 4.1.1 |
| Starters | jdbc, security, validation, mail, webmvc, oauth2-resource-server |
| Otras librerías | commons-csv 1.14.1, driver postgresql, firebase-admin 9.10.0 |
| Starters de prueba | jdbc-test, security-test, validation-test, webmvc-test |
| Base de datos | PostgreSQL 17 (esquema `public`, `database/schema.sql`) |
| Contraseñas | BCrypt, costo 12 |
| Tokens | JWT HS256 (acceso 900 s), refresh opaco 604 800 s |
| Puerto | `server.port=${PORT:8080}` |
| CORS | `app.cors.allowed-origin` (por defecto `http://localhost:5173`); permite PATCH/DELETE aunque ningún controller los usa |
| Correo | `MAIL_PROVIDER` none (por defecto) / smtp / resend |
| Push | Firebase, condicionado por `APP_FIREBASE_ENABLED` |
| Imagen | `Dockerfile` en la raíz: Flutter web + backend en una imagen |

## 3. Arquitectura

`Controller → Service (@Transactional) → Repository (JdbcTemplate, SQL parametrizado) → PostgreSQL`.
Declarado en `docs/analisis/arquitectura.md` (DA-03: JdbcTemplate con SQL explícito) y coherente con el código
leído: los controllers llaman a services, los repositories contienen SQL y no autorizan. Transversales: `config`, `security`, `exception`.
Errores con forma uniforme `{code, message}` (`ApiException`, `ApiErrorResponse`, `ApiExceptionHandler`, `SecurityErrorHandler`).

## 4. Estructura de paquetes

Raíz `uy.edu.proyecto.backend` (+ `ApiApplication`):

| Paquete | Contenido funcional |
|---|---|
| `agenda` | disponibilidad, consultas del socio, historial, agendas del funcionario |
| `atencion` | resultado de consulta (médico), historia clínica |
| `auth` | login, refresh, logout, primer ingreso, sesiones |
| `aviso` | aviso de llegada |
| `config` | SecurityConfig, JwtConfig, PasswordConfig, ClockConfig, AsyncConfig, FirebaseConfig, CORS |
| `consultorio` | alta, listado, previsualización de CSV |
| `correo` | envío de correo (none/smtp/resend) |
| `especialidad` | alta y listado |
| `estadistica` | RF-39 (integrado), RF-40 (solo en rama RF-40); `PeriodoEstadistico` compartido |
| `exception` | manejo de errores |
| `medico` | listado de médicos por especialidad |
| `notificacion` | registro de dispositivo, envío de suspensiones (listener + poller) |
| `pase` | pases disponibles del socio |
| `security` | servicios de token/sesión |
| `turno` | turnos semanales, turnos, suspensión/rehabilitación, turnos del médico |
| `usuario` | alta y padrón de usuarios, validación de CI |

## 5. Los 22 RF críticos y su estado

### Leyenda (cinco dimensiones distintas)

1. **Código**: implementado en el código.
2. **Avances**: integrado en `integracion/proyecto-2026-avances` (28b33a6).
3. **Mocks**: probado con unit/MockMvc/Mockito (se ejecuta en `mvnw verify`).
4. **PG real**: probado con PostgreSQL real en CI, solo si una `*IT` lo ejercita.
5. **Railway**: desplegado en Railway → **no verificado en esta sesión** para todos.

**Estado**: *Completo* = el comportamiento pedido está en el código, con pruebas con mocks; la columna PG real indica la evidencia extra.
*Parcial* = falta alguna parte del texto de `requerimientos.md` o falta evidencia clave. *Ausente* = sin código.
(Criterio de este informe; no es una validación formal del cliente.)

### 5.1 Resumen por dimensión

| RF | Código | Avances | Mocks | PG real (CI) | Railway | Estado |
|---|---|---|---|---|---|---|
| RF-01 | Sí | Sí | Sí | Sí (AutenticacionIT) | No verificado | Completo |
| RF-02 | Sí | Sí (PR #23) | Sí | Sí (AutenticacionIT) | No verificado | Completo |
| RF-08 | Sí | Sí | Sí | Sí (CircuitoConsultasIT) | No verificado | Completo |
| RF-09 | Sí | Sí | Sí | Sí (CircuitoConsultasIT, ConcurrenciaIT) | No verificado | Completo |
| RF-11 | Sí | Sí | Sí | Sí (CircuitoConsultasIT) | No verificado | Completo |
| RF-12 | Sí | Sí | Sí | Sí (HistoriaClinicaIT) | No verificado | **Completo** (en rama) |
| RF-13 | Sí | Sí | Sí | Sí (CircuitoConsultasIT) | No verificado | Completo |
| RF-14 | Sí | Sí | Sí | Sí (CircuitoConsultasIT, ConcurrenciaIT) | No verificado | Completo |
| RF-15 | Sí | Sí | Sí | Sí (CircuitoConsultasIT, ConcurrenciaIT) | No verificado | Completo |
| RF-16 | Sí | Sí | Sí | Sí (LlegadaAgendaMedicoIT) | No verificado | Completo |
| RF-17 | Sí | Sí | Sí | Solo permisos (RolesIT) | No verificado | Completo |
| RF-18 | Sí | Sí | Sí | Sí (LlegadaAgendaMedicoIT) | No verificado | Completo |
| RF-21 | Sí | Sí | Sí | Sí (LlegadaAgendaMedicoIT) | No verificado | Completo (sin «tiempo real») |
| RF-23 | Sí | Sí | Sí | Sí (LlegadaAgendaMedicoIT, ConcurrenciaIT) | No verificado | Completo |
| RF-24 | Parcial | Sí | Sí | Parcial (payload con `pases` en LlegadaAgendaMedicoIT) | No verificado | **Parcial** |
| RF-29 | Sí | Sí | Sí | Solo permisos (RolesIT) | No verificado | Completo |
| RF-31 | Sí | Sí | Sí | Solo permisos (RolesIT) | No verificado | Completo |
| RF-33 | Sí | Sí | Sí | Solo permisos (RolesIT) | No verificado | Completo |
| RF-35 | Sí | Sí | Sí | Solo permisos (RolesIT) | No verificado | **Parcial** |
| RF-39 | Sí | Sí (`a22eef9`) | Sí (15) | Sí (EstadisticaEspecialidadIT 6/6 en CI) | No verificado | **Completo** (en avances) |
| RF-40 | Sí | Sí (PR #25) | Sí (12) | Sí (EstadisticaTurnoIT 9/9 en CI, PR #25) | No | **Completo** (en avances, con brecha histórica) |
| RF-41 | Sí | **No** (rama RF-41) | Sí (14) | Pendiente: `EstadisticaConsultaIT` (13) corre en CI del PR de RF-41 | No | **Completo en la rama; pendiente de integración** |

### 5.2 Matriz detallada

Rutas y reglas tomadas de controllers/services/repositories. Paquetes bajo `uy.edu.proyecto.backend`.

| RF | Endpoint real | Rol | Controller | Service | Repository | DTO | Tablas | Reglas clave | Tests (clases) | Evidencia PG real | Casos alternativos | Limitaciones | Estado |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| RF-01 | `POST /api/auth/login`, `/refresh`, `/logout` | público (logout: autenticado) | AuthController | AuthService, SesionTokenService | UsuarioRepository, SesionRepository | login `{ci,password,acceso SOCIO\|EMPLEADO,plataforma WEB\|ANDROID}` | cuenta, persona, sesion | Solo cuentas habilitadas con primer ingreso completado; EMPLEADO solo WEB; error genérico `CREDENCIALES_INVALIDAS`; refresh `v2.`+32 bytes, hash SHA-256, 7 días, rotativo, cookie httpOnly path `/api/auth` | AuthControllerTest, AuthSeguridadTest, AuthServiceTest, SesionTokenServiceTest | AutenticacionIT (19) | EMPLEADO con ANDROID → 401 genérico; refresh vencido/rotado | `secure`/`sameSite` de la cookie dependen de variables (por defecto false/Lax) | Completo |
| RF-02 | `POST /api/auth/primer-ingreso/solicitar`, `/completar` | público | PrimerIngresoController | PrimerIngresoService, PrimerIngresoMailListener | repositorio de primer ingreso / enlace_cuenta | solicitar/completar | cuenta, persona, enlace_cuenta | Respuesta genérica; enlace de un solo uso, 24 h, hasheado; uno nuevo invalida los previos; `habilitada` verificada al solicitar y completar (FOR UPDATE); contraseña 8–72 bytes; correo no editable; correo vía `@Async` tras commit | PrimerIngresoControllerTest, PrimerIngresoSeguridadTest, PrimerIngresoServiceTest, PrimerIngresoMailListenerTest | AutenticacionIT | Cuenta ya activa: recibe correo de recuperación; CI inexistente: misma respuesta | CI con dígito verificador inválido devuelve 400 (no la respuesta uniforme); con `MAIL_PROVIDER=none` no sale correo | Completo |
| RF-08 | `GET /api/disponibilidad` | SOCIO | DisponibilidadController (agenda) | AgendaService | AgendaRepository | disponibilidad | turno, numero, consulta, medico_especialidad, consultorio | Solo turnos ACTIVO, ≥2 h y ≤30 d (America/Montevideo); excluye números con consulta AGENDADA; especialidad obligatoria; orden fecha\|apellidoMedico | AgendaServiceTest, AgendaRepositoryTest, DisponibilidadSeguridadTest | CircuitoConsultasIT | Sin turnos → lista vacía | El SQL no filtra médico habilitado (la reserva sí lo rechaza) | Completo |
| RF-09 | `POST /api/consultas` `{numeroId, paseId?}` | SOCIO | ConsultaController | ConsultaService | ConsultaRepository | request/response consulta | consulta, numero, turno, pase, notificacion | Bloqueos FOR UPDATE (socio, número/turno, pase); `NUMERO_NO_DISPONIBLE`, `ANTICIPACION_INVALIDA`, `LIMITE_TOTAL` (≥3), `LIMITE_ESPECIALIDAD`, `CONSULTA_SUPERPUESTA`, `PASE_NO_VALIDO`; índice único parcial `uq_consulta_numero_no_cancelada` → 409; crea fila de notificación AGENDA | ConsultaServiceTest (15), ConsultaRepositoryTest, ConsultaSeguridadTest | CircuitoConsultasIT, ConcurrenciaIT | Carrera por el mismo número → 409; pase enviado donde no se requiere → 400 | La notificación AGENDA es solo una fila, sin envío | Completo |
| RF-11 | `GET /api/consultas`, `GET /api/consultas/{id}` | SOCIO | ConsultaController | ConsultaHistorialService | ConsultaRepository | consulta resumen | consulta, aviso_llegada, atencion | Filtros estado/fechas/especialidad/médico; orden fecha\|especialidad; paginado (size ≤100); estados derivados en SQL (NO_ATENDIDA/NO_ASISTIO) | ConsultaHistorialServiceTest, ConsultaSeguridadTest | CircuitoConsultasIT (`?estado=`) | AGENDADA vencida con aviso → NO_ATENDIDA; sin aviso → NO_ASISTIO | Estados derivados no se almacenan | Completo |
| RF-12 | `GET /api/historia-clinica`, `GET /api/historia-clinica/{idAtencion}` | SOCIO | HistoriaClinicaController | HistoriaClinicaService | HistoriaClinicaRepository | HistoriaClinicaDTO (afección, tratamiento, observaciones, médico, especialidad, pases emitidos) | atencion, consulta, pase, especialidad, persona | Socio tomado del JWT; detalle filtra por socio+id (404 `HISTORIA_NO_ENCONTRADA`); filtros fechas/especialidad/médico/texto; orden fecha_atencion\|especialidad | HistoriaClinicaServiceTest, HistoriaClinicaRepositoryTest, HistoriaClinicaSeguridadTest | HistoriaClinicaIT (PostgreSQL real; resultado en el PR) | Atención ajena → 404 | Lista sin paginar por decisión; fecha en `America/Montevideo` | **Completo** (rama `feat/cierre-historia-clinica`; IT pendiente de CI) |
| RF-13 | `POST /api/turnos-semanales`, `GET /api/turnos-semanales/{id}` | FUNCIONARIO | TurnoSemanalController | TurnoSemanalService | repositorio de turno semanal (sin test propio) | request/response turno semanal | turno_semanal, numero_semanal, turno, numero | diaSemana 1–7, fin ≥ inicio, duración 10–60 min en múltiplos de 5, `MEDICO_INACTIVO`, `ESPECIALIDAD_NO_DEL_MEDICO`, `SOLAPAMIENTO_TURNO` (médico/consultorio); genera turnos y números por fecha; FOR UPDATE | TurnoSemanalServiceTest (10), TurnoSemanalSeguridadTest | CircuitoConsultasIT | Solapamiento → 409 | No existe `TurnoSemanalRepositoryTest` | Completo |
| RF-14 | `POST /api/turnos/suspensiones/previsualizar`, `POST /api/turnos/suspensiones` | FUNCIONARIO | TurnoFechasController | TurnoFechasService | repositorio de fechas de turno | previsualización/confirmación | turno, turno_evento, consulta, notificacion, envio_notificacion | Previsualizar y confirmar; `CONFIRMACION_DESACTUALIZADA`; `TURNO_NO_SUSPENDIBLE` (hoy/futuro); observación ≤1000; consultas AGENDADA → CANCELADA_INSTITUCION con `id_evento_suspension`; pases quedan libres por derivación; notificaciones SUSPENSION | TurnoFechasServiceTest (10), TurnoFechasRepositoryTest, TurnoFechasSeguridadTest | CircuitoConsultasIT, ConcurrenciaIT | Reserva vs suspensión simultáneas | Efectivamente solo el canal correo funciona (ver sección 7) | Completo |
| RF-15 | `POST /api/turnos/rehabilitaciones` | FUNCIONARIO | TurnoFechasController | TurnoFechasService | ídem | ídem | turno, turno_evento | `TURNO_NO_REHABILITABLE`; revalida `MEDICO_INACTIVO` y `SOLAPAMIENTO_TURNO` | TurnoFechasServiceTest, TurnoFechasSeguridadTest | CircuitoConsultasIT, ConcurrenciaIT | Rehabilitaciones solapadas simultáneas | Las consultas canceladas no se reactivan (comportamiento coherente con la regla) | Completo |
| RF-16 | `POST /api/avisos-llegada`, `GET /api/avisos-llegada/consultas-hoy?ci=` | FUNCIONARIO | AvisoLlegadaController | AvisoLlegadaService | AvisoLlegadaRepository | aviso | aviso_llegada, consulta, cuenta | Idempotente por socio+fecha (UNIQUE `uq_aviso_llegada_socio_fecha`; 201 al crear, 200 si ya existe); `CONFLICTO_INTERES` 403; `SIN_CONSULTAS_AGENDADAS` 409 | AvisoLlegadaServiceTest, AvisoLlegadaRepositoryTest, AvisoLlegadaSeguridadTest | LlegadaAgendaMedicoIT | Repetir aviso | — | Completo |
| RF-17 | `GET /api/turnos` (filtros médico/especialidad/diaSemana/fechas/estado/orden/page) | FUNCIONARIO | TurnoConsultaController | TurnoConsultaService | TurnoConsultaRepository | turno resumen | turno, medico, consultorio, especialidad | Estados ACTIVO/SUSPENDIDO; orden fecha\|medico\|especialidad; sentido asc/desc | TurnoConsultaServiceTest, TurnoConsultaRepositoryTest, TurnoConsultaSeguridadTest | Solo permisos (RolesIT) | Parámetros inválidos → 400 | Filtros sin IT funcional | Completo |
| RF-18 | `GET /api/agendas` (ci, consultaId, fecha, medicoId, estado, llegada, orden fechaHora\|horaLlegada, sentido, page, size) | FUNCIONARIO | AgendaConsultaController | AgendaConsultaService | AgendaConsultaRepository | agenda | consulta, numero, turno, aviso_llegada | Filtros y orden por llegada | AgendaConsultaServiceTest, AgendaConsultaRepositoryTest, AgendaConsultaSeguridadTest | LlegadaAgendaMedicoIT | — | — | Completo |
| RF-21 | `GET /api/medico/turnos?fecha=`, `GET /api/medico/turnos/{id}/numeros` | MEDICO | TurnoMedicoController | TurnoMedicoService | TurnoMedicoRepository | turnos/números del médico | turno, numero, consulta, aviso_llegada, persona | Números con paciente, estado de consulta, `llegadaEn`, `disponible`; orden hora\|horaLlegada | TurnoMedicoServiceTest, TurnoMedicoRepositoryTest, TurnoMedicoSeguridadTest | LlegadaAgendaMedicoIT | — | No hay SSE/WebSocket: el «tiempo real» se resuelve solo consultando de nuevo | Completo (con esa limitación) |
| RF-23 | `POST /api/medico/consultas/{id}/resultado` | MEDICO | AtencionController | AtencionService | AtencionRepository | `{resultado, afeccion, tratamiento, observaciones, pases[]}` | consulta, atencion, pase, notificacion | Orden: `CONFLICTO_DE_INTERES` 403, `CONSULTA_NO_AGENDADA`, `CONSULTA_NO_ES_DE_HOY`, `SIN_AVISO_LLEGADA`; ATENDIDA exige afección; NO_SE_PRESENTO sin datos clínicos ni pases; @Transactional con bloqueo de socio y consulta | AtencionServiceTest, AtencionRepositoryTest, AtencionSeguridadTest | LlegadaAgendaMedicoIT, ConcurrenciaIT (resultados incompatibles) | NO_SE_PRESENTO | Notificación HISTORIA_ACTUALIZADA solo como fila | Completo |
| RF-24 | misma ruta de RF-23 (emisión) + `GET /api/socios/me/pases/disponibles` (consulta) | MEDICO / SOCIO | AtencionController / PaseController | AtencionService / servicio de pases | AtencionRepository | `pases:[{especialidadDestinoId, vigenciaDias}]` | pase, atencion | Sin duplicar especialidades; vigencia 1–365 (por defecto 90); `PASE_DUPLICADO` si ya hay pase válido o consulta AGENDADA en esa especialidad; `vence_el = hoy + días`; se consume al reservar (RF-09) | AtencionServiceTest, PaseDisponiblesTest | Parcial: payload con `pases` en LlegadaAgendaMedicoIT; `/api/socios/me/pases/disponibles` sin IT | PASE_DUPLICADO; pase de especialidad sin requisito | La devolución del pase al cancelar el socio depende de RF-10 (cancelación por el socio), **no implementada**; solo se libera vía suspensión (derivación SQL) | Parcial |
| RF-29 | `POST /api/especialidades`, `GET /api/especialidades` | ADMIN (GET: cualquier autenticado) | EspecialidadController | EspecialidadService | repositorio de especialidad | especialidad | especialidad | Nombre ≤120; único sin distinguir mayúsculas (`uq_especialidad_nombre` sobre `lower(nombre)`); `ESPECIALIDAD_DUPLICADA` 409 | EspecialidadServiceTest, EspecialidadControllerTest, EspecialidadSeguridadTest | Solo permisos (RolesIT) | Duplicado | Sin endpoint para modificar `requiere_pase` | Completo |
| RF-31 | `POST /api/usuarios` | ADMIN | AltaUsuarioController | AltaUsuarioService | repositorio de usuario | alta / `CuentaCreadaResponse` (201) | persona, cuenta, medico_especialidad | CI uruguaya con dígito verificador, correo, roles, teléfono ≤30; MEDICO requiere ≥1 especialidad y los demás ninguna; `DATOS_PERSONA_DISCORDANTES`, `SOCIO_DUPLICADO`, `EMPLEADO_DUPLICADO` | AltaUsuarioServiceTest, AltaUsuarioControllerTest, AltaUsuarioSeguridadTest, CiUruguayaTest | Solo permisos (RolesIT) | Persona existente con otros datos | No envía correo (el primer ingreso lo inicia el usuario, RF-02) | Completo |
| RF-33 | `POST /api/consultorios`, `GET /api/consultorios`, `POST /api/consultorios/importaciones/previsualizar` | ADMIN (GET: cualquier autenticado) | ConsultorioController | ConsultorioService, ConsultorioImportacionService | repositorio de consultorio | consultorio | consultorio | Nombre ≤120 y ubicación ≤200 obligatorios; `nombre` único exacto (sensible a mayúsculas) → `CONSULTORIO_DUPLICADO` | ConsultorioServiceTest, ConsultorioControllerTest, ConsultorioSeguridadTest, ConsultorioCsv* (Parser, Validador, Previsualizador), ConsultorioImportacionServiceTest | Solo permisos (RolesIT) | Duplicado | El ejemplo del RF habla de «nombre o número único»; el código solo tiene `nombre` | Completo |
| RF-35 | `GET /api/usuarios` (rol, estado ACTIVA\|INACTIVA, texto, page, size ≤100) | ADMIN | AltaUsuarioController | UsuarioService | UsuarioPadronRepository | id, ci, nombre, apellido, rol, correo, estado, activada, fechaAlta | cuenta, persona | Una fila por cuenta; `texto` busca por CI o apellido; orden apellido ASC, fecha_alta DESC | UsuarioServiceTest, UsuarioRepositoryTest, AltaUsuarioControllerTest, AltaUsuarioSeguridadTest | Solo autorización (RolesIT); filtros sin IT | — | No hay endpoint para activar/inactivar cuentas; contrato-v1 propone `q` y el código usa `texto`; contraste fino con el texto del RF sin evidencia contra PostgreSQL | Parcial |
| RF-39 | `GET /api/estadisticas/especialidades?desde&hasta` | ADMIN | EstadisticaEspecialidadController | EstadisticaEspecialidadService | EstadisticaEspecialidadRepository | `{desde,hasta,items:[{especialidad:{id,nombre,requierePase},cantidadConsultas}]}` | consulta, numero, turno, especialidad | Cuenta consultas por `agendada_en` en [desde, hasta+1 día) America/Montevideo; LEFT JOIN: especialidades con 0 aparecen; incluye canceladas; orden cantidad DESC, nombre, id; por defecto mes actual | EstadisticaEspecialidadServiceTest 8, EstadisticaEspecialidadRepositoryTest 1, EstadisticaSeguridadTest 6 (= 15) | EstadisticaEspecialidadIT 6/6 en CI | Sin datos; rangos inválidos; sin parámetros | Integrado en `avances` (PR #24, `a22eef9`); `endpoints-usados.md` #34 CONFIRMADA | Completo |
| RF-40 | `GET /api/estadisticas/turnos?desde&hasta` | ADMIN | EstadisticaController | EstadisticaTurnoService | EstadisticaTurnoRepository | `{desde,hasta,items:[{turnoSemanalId,medico,especialidad,consultorio,diaSemana,fechasActivas,numerosOfrecidos,numerosOcupados,porcentajeUtilizacion,utilizacion}]}` | turno_semanal, turno, numero, consulta, medico, especialidad, consultorio | ocupados/ofrecidos×100 sobre fechas con `turno.estado='ACTIVO'`; ocupado = existe consulta no cancelada (EXISTS, sin doble conteo); denominador 0 = "Sin datos"; mes actual por defecto, America/Montevideo | ServiceTest 7, RepositoryTest 1, SeguridadTest +4 | EstadisticaTurnoIT 9/9 en CI (PR #25) | Período vacío, fechas suspendidas/rehabilitadas, reserva repetida | **Limitación / brecha funcional**: «activa» usa el estado actual de la fecha; el RF dice «estuvo activa» y no se reconstruye el historial de `turno_evento` (pendiente de decisión del grupo). Integrado en `avances` (PR #25) | Completo (con brecha histórica) |
| RF-41 | `GET /api/estadisticas/consultas?desde&hasta` | ADMIN | EstadisticaController | EstadisticaConsultaService | EstadisticaConsultaRepository | `{desde,hasta,estados:{7 estados},totalConsultas,canceladasPorSocio,porcentajeCancelacion,porcentajeCancelacionTexto}` | consulta, numero, turno, aviso_llegada | Período sobre `turno.fecha` (no `agendada_en`); estado efectivo: AGENDADA sin resultado y día terminado = NO_ATENDIDA (con aviso) o NO_ASISTIO (sin aviso), America/Montevideo; GROUP BY estado efectivo, una fila por consulta; tasa = canceladas por socio / total ×100; total 0 = "Sin datos" | EstadisticaConsultaServiceTest 8, EstadisticaConsultaRepositoryTest 1, EstadisticaSeguridadTest +5 | EstadisticaConsultaIT (13), ejecutada en CI del PR de RF-41 | Período vacío, 0 %, 100 %, hoy/futuro, límites, fechas inválidas | La regla de estados derivados está duplicada en SQL con las consultas de agenda e historial; no se reconstruye el estado en fechas pasadas. En rama, sin integrar | Completo en la rama; pendiente de integración |

### 5.3 Qué falta en los RF parciales (a contrastar con `docs/analisis/requerimientos.md`)

- **RF-12**: el listado debería poder paginarse y el contrato-v1 propone un resumen paginado; el código devuelve una lista completa con campos clínicos. No hay IT que pruebe que un socio no ve historias ajenas con PostgreSQL real.
- **RF-24**: la emisión y el uso del pase funcionan; el flujo en que el pase vuelve a estar disponible cuando el **socio** cancela no existe porque no hay cancelación por el socio. Los pases disponibles no tienen IT.
- **RF-35**: listado y filtros en el código, sin prueba funcional con PostgreSQL ni gestión de estado de cuentas. Se marca parcial por falta de evidencia, no por un defecto demostrado.
- **RF-39**: completo, integrado en `avances` y confirmado con PostgreSQL en CI.
- **RF-40**: completo y validado en CI; integrado en `avances` (PR #25). Brecha funcional histórica («estuvo activa») pendiente de decisión del grupo.
- **RF-41**: completo en la rama `feat/rf-41-estadisticas-consultas`; pendiente de integración; la validación PostgreSQL (`EstadisticaConsultaIT`) se registra en su PR.

### 5.4 Contradicciones entre documentos y código

1. `docs/api/endpoints-usados.md` marca #34, #35 (integradas) y #36 (RF-41, solo en su rama) como CONFIRMADAS.
2. `endpoints-usados.md` lista `POST /api/consultas/{id}/cancelar` (#20), `GET /api/notificaciones` (#32) y `POST /api/dispositivos` (#33) como propuestos; **no existen**. La ruta real del registro de dispositivo es `POST /api/notificaciones/registro`.
3. contrato-v1: `q` vs `texto` real en `GET /api/usuarios`; historia clínica paginada vs lista real.
4. `docs/informes/auditoria-backend-criticos.md` está desfasado: describe RF-02 como parcial y cita `docs/especificaciones/backend_criticos_2026.md`, que no existe; es anterior al PR #23.
5. `docs/pruebas-integracion.md` no menciona las IT de estadísticas (`EstadisticaEspecialidadIT`, `EstadisticaTurnoIT`).
6. `docs/integracion/estado-2026-10-21.md` habla de 34 pruebas HTTP reales; hoy las IT son 54 en la rama RF-40 (45 en `avances`).
7. El manual de consola se actualiza en esta rama con RF-40 (sección 5.10).

## 6. Endpoints completos por rol

Fuente: `@*Mapping` de los controllers y `SecurityConfig`. **No existe ningún PATCH ni DELETE** en los controllers (solo GET y POST).
`anyRequest` exige autenticación; los recursos estáticos de Flutter web (`/`, `index.html`, assets) son públicos.

### Públicos
| Método | Ruta | Notas |
|---|---|---|
| POST | `/api/auth/login` | |
| POST | `/api/auth/refresh` | usa cookie |
| POST | `/api/auth/primer-ingreso/solicitar` | responde 202 |
| POST | `/api/auth/primer-ingreso/completar` | responde 200 |

### Cualquier usuario autenticado
| Método | Ruta | Notas |
|---|---|---|
| POST | `/api/auth/logout` | 204 |
| GET | `/api/especialidades` | |
| GET | `/api/consultorios` | |
| POST | `/api/notificaciones/registro` | body `{fid}` |

### ADMINISTRADOR
| Método | Ruta | Notas |
|---|---|---|
| POST | `/api/usuarios` | 201 |
| GET | `/api/usuarios` | rol, estado, texto, page, size ≤100 |
| POST | `/api/especialidades` | 201 |
| POST | `/api/consultorios` | 201 |
| POST | `/api/consultorios/importaciones/previsualizar` | multipart `archivo` (CSV: nombre, ubicacion); solo previsualiza |
| GET | `/api/estadisticas/especialidades` | desde, hasta (RF-39, integrado) |
| GET | `/api/estadisticas/turnos` | desde, hasta; **solo en la rama RF-40** |
| — | `/api/admin/**` | reservado en SecurityConfig, sin controller |

### FUNCIONARIO
| Método | Ruta |
|---|---|
| POST | `/api/turnos-semanales` (201) |
| GET | `/api/turnos-semanales/{id}` |
| GET | `/api/turnos` |
| POST | `/api/turnos/suspensiones/previsualizar` |
| POST | `/api/turnos/suspensiones` |
| POST | `/api/turnos/rehabilitaciones` |
| GET | `/api/medicos?especialidadId=` |
| GET | `/api/agendas` |
| GET | `/api/avisos-llegada/consultas-hoy?ci=` |
| POST | `/api/avisos-llegada` (201 al crear, 200 si ya existía) |

### SOCIO
| Método | Ruta |
|---|---|
| GET | `/api/disponibilidad` |
| POST | `/api/consultas` (201) |
| GET | `/api/consultas` |
| GET | `/api/consultas/{id}` |
| GET | `/api/socios/me/pases/disponibles` |
| GET | `/api/historia-clinica` |
| GET | `/api/historia-clinica/{idAtencion}` |

### MEDICO
| Método | Ruta |
|---|---|
| GET | `/api/medico/turnos?fecha=` |
| GET | `/api/medico/turnos/{id}/numeros` |
| POST | `/api/medico/consultas/{id}/resultado` |

### Propuestos en documentos pero **no implementados**
`POST /api/consultas/{id}/cancelar`, `GET /api/notificaciones`, `POST /api/dispositivos`, `/api/estadisticas/turnos` (RF-40), `/api/estadisticas/consultas` (RF-41), recuperación de contraseña (RF-05), correcciones (RF-38), confirmación de importación CSV.

## 7. Funcionalidades no críticas existentes

Verificadas en código:
- Refresh y logout con rotación de sesión (RF-01 las incluye).
- `POST /api/notificaciones/registro`: guarda el registro Firebase en un `ConcurrentHashMap` en memoria (`FirebaseRegistrationStore`); se pierde al reiniciar. Nada escribe en `dispositivo_push`, de modo que el canal push de suspensiones que lee esa tabla no tiene datos: en la práctica solo el correo (no verificado en ejecución).
- Envío de suspensiones: listener AFTER_COMMIT + `EnvioSuspensionPoller` (`@Scheduled` 30 s, ≤100 por ciclo, `FOR UPDATE SKIP LOCKED`).
- Previsualización de CSV de consultorios (solo previsualiza; **no hay endpoint que confirme/persiste la importación**).
- `GET /api/especialidades`, `GET /api/consultorios`, `GET /api/medicos`.
- Notificaciones AGENDA y HISTORIA_ACTUALIZADA: solo se inserta la fila; no se envían.
- Tablas `anuncio` / `imagen_anuncio`: sin controller.

## 8. Base de datos y relaciones

`database/schema.sql` (zona horaria America/Montevideo). Tablas: persona, cuenta, especialidad, medico_especialidad, sesion, enlace_cuenta, consultorio, turno_semanal, numero_semanal, turno, numero, aviso_llegada, turno_evento, consulta, atencion, pase, anuncio, imagen_anuncio, notificacion, dispositivo_push, envio_notificacion.

Relaciones principales: persona 1–N cuenta (socio/empleado); medico_especialidad une cuenta–especialidad; turno_semanal genera turno y numero; consulta referencia numero, socio y, opcionalmente, pase y evento de suspensión; atencion 1–1 consulta; pase nace de una atención y apunta a una especialidad destino.

Restricciones relevantes: `ck_consulta_estado` (AGENDADA, ATENDIDA, CANCELADA_SOCIO, CANCELADA_INSTITUCION, NO_SE_PRESENTO; NO_ASISTIO y NO_ATENDIDA se **derivan**); `uq_cuenta_socio_ci`; `uq_cuenta_empleado_habilitado_ci` (parcial); `uq_especialidad_nombre` (lower); `uq_consulta_numero_no_cancelada` y `uq_consulta_pase_no_cancelada` (parciales); `uq_aviso_llegada_socio_fecha`; `uq_atencion_consulta`; `uq_pase_atencion_destino`; `uq_turno_patron_fecha`; intervalos de números múltiplos de 5; `notificacion.tipo` ∈ AGENDA/CANCELACION/SUSPENSION/HISTORIA_ACTUALIZADA/RECORDATORIO. `enlace_cuenta.tipo` admite RECUPERACION/CAMBIO_CORREO sin código asociado.

## 9. Autenticación y seguridad

- JWT HS256 (900 s), claim `role`, `sub` = id de cuenta; resource server de Spring Security.
- Refresh opaco con hash SHA-256 en `sesion`, 7 días, rotado en cada uso; cookie httpOnly, path `/api/auth`.
- BCrypt costo 12; contraseña 8–72 bytes.
- Reglas por rol en `SecurityConfig` (secciones 6 y 12 de este informe): ADMIN (`/api/usuarios`, `/api/estadisticas/**`, creación de especialidades/consultorios), FUNCIONARIO, SOCIO, MEDICO; el resto de `/api/**` exige autenticación.
- Conflicto de interés: el funcionario/médico no puede operar sobre su propia CI (RF-16, RF-23).
- Errores 401/403 con formato uniforme (`SecurityErrorHandler`).
- Vigencia de cuenta (integrada en `avances` mediante PR #26): antes de este cambio el `JwtDecoder` solo validaba firma, emisor y expiración, por lo que el JWT de una cuenta inactivada seguía siendo válido hasta 900 s. `CuentaVigenteValidator` consulta `cuenta` en cada solicitud (sin caché), exige cuenta habilitada, rol coincidente e `iat` posterior a la última reactivación; ante fallo de BD responde 401. `SesionRepository.rotar` no renueva sesiones previas a una reactivación. Pruebas: `CuentaVigenteValidatorTest` (11) y `CuentasInactivasIT`. Riesgos: `iat` con precisión de segundos; una solicitud en curso no se interrumpe.
- No verificado: configuración real de `COOKIE_SECURE`/`COOKIE_SAME_SITE` en producción.

## 10. Transacciones y concurrencia

- Services con `@Transactional`; bloqueos `FOR UPDATE` en reserva (socio, número/turno, pase), alta de turnos (médico, consultorio), suspensión/rehabilitación (turno, consultas, números, médico, consultorio), atención (socio y consulta) y primer ingreso.
- Índices únicos parciales como segunda barrera; `DuplicateKeyException` → 409.
- `ConcurrenciaIT` (5 escenarios, 8 rondas cada uno): mismo número, reserva vs suspensión, suspensión vs rehabilitación, rehabilitaciones solapadas, resultados incompatibles. Aprobados en CI antes de RF-39.
- Correo de primer ingreso y notificaciones de suspensión se despachan después del commit.

## 11. Pases, cancelaciones y estados derivados

- Emisión: al registrar ATENDIDA (RF-23/24). Uso: al reservar (RF-09). Disponibilidad derivada: un pase está libre si no existe consulta no cancelada que lo use.
- Cancelación por institución (suspensión de turno): consultas → CANCELADA_INSTITUCION, el pase se libera por derivación.
- Cancelación por el socio (RF-10): **no implementada**; CANCELADA_SOCIO existe en el esquema pero ningún endpoint lo produce.
- NO_ATENDIDA / NO_ASISTIO: derivados en SQL para AGENDADA vencida sin resultado.

## 12. Tests unitarios / HTTP / seguridad / integración

- Anotaciones contadas: 340 no-IT (+18 por expansión de `@ParameterizedTest` en `GuardaBaseE2ETest`) = **358 con RF-39 / 343 sin él**, coincidente con el dato confirmado. IT: 39 + 6 (RF-39) = 45.
- Unit/Mockito (services y repositories con mocks), MockMvc `@WebMvcTest` + `SecurityConfig` (clases `*SeguridadTest`), y 18 pruebas de contexto (`ApiApplicationTests` 1, `ConsultorioControllerTest` 5, `ConsultorioSeguridadTest` 4, `EspecialidadControllerTest` 4, `EspecialidadSeguridadTest` 4; `@SpringBootTest` con `@MockitoBean`).
- Surefire solo define variables de entorno; sin Failsafe. Sus inclusiones por defecto no toman `*IT`, por eso `mvnw verify` no las ejecuta.
- IT (PostgreSQL real): AutenticacionIT 19, CircuitoConsultasIT 4, ConcurrenciaIT 5, LlegadaAgendaMedicoIT 6, RolesIT 5 (= 39) y EstadisticaEspecialidadIT 6 (RF-39).
- No cubierto por ninguna IT funcionalmente: RF-12, `/api/medicos`, `/api/socios/me/pases/disponibles`, filtros de RF-17 y RF-35, altas de RF-29/31/33.
- RF-39: 15 pruebas con mocks (ServiceTest 8, RepositoryTest 1, SeguridadTest 6).

## 13. Validación PostgreSQL real disponible

- `.github/workflows/e2e.yml`: se dispara en PR y push a `integracion/proyecto-2026-avances`; levanta PostgreSQL 17 efímero (`proyecto_e2e`), carga `schema.sql`, ejecuta `verificar_esquema.sql`, corre `mvnw test -Dtest='*IT'` (falla si hay 0 IT o alguna omitida) y luego las 5 clases de contexto; sube reportes Surefire.
- `backend.yml`: `./mvnw -B verify` con servicio postgres:17. `esquema.yml`, `imagen.yml` (build Docker y humo: `/` sirve `flutter_bootstrap.js`, `/api/especialidades` → 401), `frontend.yml`.
- Resultado confirmado para `avances`: 39 IT + 18 de contexto aprobadas. **RF-39**: `EstadisticaEspecialidadIT` aprobó 6/6 en CI (PR #24, commit 528201d; total 45/45 IT).
- Seguridad de la base de pruebas (`GuardaBaseE2E`): solo host local, nombre `*_e2e`/`*_test`, `E2E_ALLOW_DESTRUCTIVE=true` y comentario `proyecto-e2e-descartable`.

## 14. Documentación generada

`README.md`, `docs/analisis/requerimientos.md`, `docs/analisis/arquitectura.md`, `docs/api/endpoints-usados.md`, `docs/api/contrato-v1.md`, `docs/api/railway-correo.md`, `docs/pruebas-integracion.md`, `docs/manual-backend-consola.md`, `docs/integracion/estado-2026-10-21.md`, `docs/informes/auditoria-backend-criticos.md`, `database/README.md`. Desfases en 5.4.

## 15. Estado de GitHub y ramas

- `integracion/proyecto-2026-avances` = `a55dbda6fb3ab9c22433a0e4ca0423cb75cdb213`, con RF-02 (PR #23), RF-39 (PR #24), RF-40 (PR #25) y la corrección JWT (PR #26) fusionados.
- `main` = `39dae5c7f9a780914917876160f1e59f0bbfb522`, intacta (ancestro de `avances`).
- `feat/rf-41-estadisticas-consultas`: creada desde `a55dbda`; PR hacia `avances` para CI, sin fusionar.
- Otras ramas remotas: `feat/rf-02-primer-ingreso`, `feat/pases-disponibles`, `test/e2e-postgresql-2026`, `integracion/pr-19-segura-2026-10-23`.

## 16. Estado conocido de Railway

**No verificado en esta sesión.** Lo que consta en el repo:
- `docs/analisis/arquitectura.md` describe el destino (Railway + PostgreSQL 17 en Supabase vía Supavisor).
- `docs/api/railway-correo.md` lista variables (PORT, DB_URL/DB_USER/DB_PASSWORD, JWT_SECRET_BASE64, CORS_ALLOWED_ORIGIN, COOKIE_SECURE, COOKIE_SAME_SITE, APP_FIREBASE_ENABLED, MAIL_PROVIDER=resend, RESEND_API_KEY, MAIL_FROM, FIRST_LOGIN_URL) y avisa que Railway bloquea SMTP en planes Free/Trial/Hobby.
- `docs/integracion/estado-2026-10-21.md`: «despliegue en Railway (no realizado)». `docs/pruebas-integracion.md` lo lista como «No cubierto».
- No se afirma ningún despliegue de RF-39, RF-40 ni RF-41.

## 17. Pendientes

1. Revisar y fusionar el PR de RF-41 tras confirmar `EstadisticaConsultaIT` en CI.
2. Decidir la brecha histórica de RF-40 («estuvo activa», `turno_evento`).
3. RF-12: alinear contrato (paginación) y agregar IT de propiedad con PostgreSQL.
4. RF-24: IT de pases disponibles; RF-10 (cancelación por el socio) para devolver pases.
5. RF-35: IT funcional de filtros; decidir gestión de estado de cuentas.
6. Persistir el registro de dispositivo en `dispositivo_push` (hoy en memoria).
7. Enviar notificaciones AGENDA/HISTORIA_ACTUALIZADA; RF-21 en tiempo real si se exige.
8. Confirmación de la importación CSV de consultorios.
9. Filtrar médico habilitado en la disponibilidad (RF-08).
10. Actualizar documentos desfasados (5.4) y, si se quiere, agregar Failsafe para que `verify` ejecute las IT.
11. Verificar y documentar el despliegue en Railway.

## 18. Plan de implementación (orden recomendado)

1. **Cerrar RF-41**: revisar y fusionar su PR tras el CI. RF-39 (PR #24), RF-40 (PR #25) y la corrección JWT (PR #26) ya están integrados. Pendiente: `pruebas-integracion.md` no menciona las IT de estadísticas.
2. **Brecha de RF-40**: decidir si «estuvo activa» exige reconstruir `turno_evento`.
3. **RF-12**, luego **RF-24 y RF-10**, **RF-35** (ver más abajo), RF-08 y RF-21.
4. **RF-12**: paginación/contrato + IT de propiedad.
5. **RF-24 y RF-10**: cancelación por el socio, devolución del pase e IT.
6. **RF-35**: IT funcional y definición del estado de cuentas.
7. Persistencia de dispositivos, envíos de notificaciones y confirmación de CSV (no críticos).
8. Verificación en Railway y actualización documental final.
