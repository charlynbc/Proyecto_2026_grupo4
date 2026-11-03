# Pruebas de integración con PostgreSQL 17

Pruebas HTTP reales del backend (Spring Boot en puerto aleatorio, cliente
`java.net.http`) contra un PostgreSQL 17 **aislado y descartable**. Viven en
`backend/api/src/test/java/uy/edu/proyecto/backend/integracion/` y se llaman
`*IT`, por lo que `./mvnw verify` normal no las ejecuta.

> **Nota del 30/10/2026:** el cliente Flutter sondea cada 15 s desde el PR #43. `MedicoTurnosTiempoRealIT` usa su propio intervalo de 3 s (`SONDEO_MS`), y la latencia medida de ~1,8 s corresponde a ese valor.

## Aislamiento

- `GuardaBaseE2E` valida todo **antes** de conectar: host `localhost`/`127.0.0.1`, nombre en minúsculas `[a-z][a-z0-9_]*` terminado en `_e2e` o `_test` (sin mayúsculas, dígito inicial, guiones, parámetros ni `;`) y la variable `E2E_ALLOW_DESTRUCTIVE=true`. Cualquier otra combinación aborta sin tocar nada.
- El nombre se entrecomilla como identificador SQL y las consultas usan parámetros.
- Si la base ya tiene tablas, solo se reinicializa si tiene el comentario `proyecto-e2e-descartable` (`COMMENT ON DATABASE`). Las bases creadas por las pruebas se marcan solas; una base ajena con tablas se rechaza sin modificarse. En Actions el workflow marca la base efímera.
- Antes de cada clase recrea el esquema `public` y carga `database/schema.sql`.
- Antes de cada prueba vacía todas las tablas y siembra datos ficticios (admin, 2 funcionarios, médico, socios, especialidades, consultorio). Contraseña ficticia común: `Clave-Segura-1`.
- Firebase y correo externo están desactivados; el enlace de primer ingreso se captura con un listener del evento `PrimerIngresoLinkSolicitado`.

## Ejecución local

```powershell
# PostgreSQL 17 local descartable (ejemplo: puerto 55432)
cd backend\api
$env:E2E_DB_URL = "jdbc:postgresql://localhost:55432/proyecto_e2e"
$env:E2E_DB_USER = "postgres"; $env:E2E_DB_PASSWORD = "postgres"; $env:E2E_ALLOW_DESTRUCTIVE = "true"
.\mvnw.cmd test "-Dtest=*IT" "-Dsurefire.failIfNoSpecifiedTests=false"

# Clases de contexto completo (exigen base con esquema y Firebase apagado)
$env:DB_URL = $env:E2E_DB_URL; $env:DB_USER = "postgres"; $env:DB_PASSWORD = "postgres"
$env:JWT_SECRET_BASE64 = "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY="
$env:APP_FIREBASE_ENABLED = "false"
.\mvnw.cmd test "-Dtest=ApiApplicationTests,ConsultorioControllerTest,ConsultorioSeguridadTest,EspecialidadControllerTest,EspecialidadSeguridadTest"
```

## En GitHub Actions

`.github/workflows/e2e.yml` (PR hacia y push a `integracion/proyecto-2026-avances`) levanta `postgres:17` como servicio, carga el esquema, corre `verificar_esquema.sql`, las `*IT` y las 5 clases de contexto completo. Falla si falla cualquier prueba. Los reportes quedan como artefacto. Los demás workflows (Backend, Frontend con `flutter build web --release`, Imagen, Esquema) corren por separado.

## Cobertura

| Clase | Cubre |
|---|---|
| `AutenticacionIT` | RF-01/02: login, refresh con rotación, logout con token válido y vencido (refresh sin bearer + reintento), primer ingreso (completo, inválido, reutilizado, expirado) |
| `CircuitoConsultasIT` | RF-08/09/11/13/14/15: turnos, disponibilidad, reserva, reglas de anticipación/pase, historial, suspensión y rehabilitación |
| `LlegadaAgendaMedicoIT` | RF-16/18/21/23: llegada, agendas, resultado médico, conflicto de interés |
| `RolesIT` | Matriz endpoint × rol (401/403/permitido), base intacta tras los rechazos, recursos públicos de Flutter |
| `ConcurrenciaIT` | 5 escenarios con barrera: misma reserva, reserva vs suspensión, suspensión vs rehabilitación, rehabilitaciones solapadas, resultados incompatibles (8 rondas c/u) |
| `CancelacionConsultaIT` (18), `HistoriaClinicaIT` (18), `CuentasInactivasIT` (15) | Cancelación y devolución de pase (RF-10), historia clínica (RF-12), cuentas inactivadas |
| `MedicoIT` (4) | `GET /api/medicos` como lista JSON, filtro y habilitados; consumo por Flutter (selector de turno semanal) |
| `ReservasTrasInasistenciaIT` (9) | Reserva tras NO_ASISTIO/NO_ATENDIDA, límites de 3 y por especialidad, cambio de día |
| `PasesRF24IT` (13), `PasesEscenariosRF24IT` (4, PR #36) | RF-24: emisión, vigencia 90 d y 1–365, duplicados, consumo, devolución, sin devolución por inasistencia, atención repetida, circuito completo, concurrencia |
| `PadronUsuariosIT` (9) | RF-35: `q`/`texto`, `orden`, `sentido`, paginación, `%`/`_` literales, una fila por cuenta, seguridad |
| `CargaMasivaEspecialidadesIT` (9) | RF-30: previsualizar sin insertar, confirmar con éxito parcial, duplicados en archivo y en base (sin actualizar), `requiere_pase` inválido, archivo vacío y cabeceras incorrectas, punto y coma y campos entrecomillados, roles, concurrencia sin duplicar, regresión RF-29 |
| `CargaMasivaUsuariosIT` (14) | RF-32: alta de socio/médico/funcionario, cuenta pendiente sin correo ni activación, CI inválida, cuenta duplicada, persona coincidente y discordante, especialidad inexistente, obligatorias faltantes, rol inválido, empleado habilitado, fila repetida, roles, concurrencia sin duplicar, regresión RF-31 |
| `Estadistica{Especialidad,Turno,Consulta}IT` | RF-39/40/41 |
| `DisponibilidadIT` (2) | RF-08: solo médicos habilitados y turnos activos |
| `EstadisticaTurnoHistoricoIT` (12) | RF-40 histórico desde `turno_evento` |
| `MedicoTurnosTiempoRealIT` (7) | RF-21: roles, médico ajeno, cambios de otros actores y dos clientes con sondeo de 3 s (latencia medida ~1,8 s) |

Totales verificados sobre el HEAD `25405b4` de avances: **182 IT**, **419** pruebas Maven (sin IT) y **909** pruebas Flutter, 0 fallos; ver `docs/informes/cierre-criticos-2026.md`.

## Hallazgos

- Reservar un número ya tomado devolvía 500 por el índice único parcial `uq_consulta_numero_no_cancelada`; ahora responde 409 `NUMERO_NO_DISPONIBLE` (`ConsultaService`).
- El servidor rechaza con 401 un bearer vencido incluso en `/api/auth/refresh`; por eso el cliente nunca debe enviarlo.

## No cubierto

- Navegador automatizado (Flutter web contra el backend real); las pruebas Flutter son unitarias y de widgets.
- Notificación inmediata (push/SSE) de RF-21: se resolvió con sondeo de 3 s; no se probó en navegador real.
- Limitación de RF-40: un turno sin eventos en `turno_evento` usa su estado actual.
- Docker local (se verifica solo en Actions, workflow Imagen).
- Envío real de correo (Resend) y push Firebase.
- Despliegue en Railway.
