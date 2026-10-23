# Pruebas de integración con PostgreSQL 17

Pruebas HTTP reales del backend (Spring Boot en puerto aleatorio, cliente
`java.net.http`) contra un PostgreSQL 17 **aislado y descartable**. Viven en
`backend/api/src/test/java/uy/edu/proyecto/backend/integracion/` y se llaman
`*IT`, por lo que `./mvnw verify` normal no las ejecuta.

## Aislamiento

- `BaseIntegracionIT` solo acepta URLs `jdbc:postgresql://localhost|127.0.0.1[:puerto]/<nombre>_e2e|_test`. Cualquier otra (Supabase, Railway, etc.) aborta la prueba antes de conectar.
- Antes de cada clase recrea el esquema `public` y carga `database/schema.sql`.
- Antes de cada prueba vacía todas las tablas y siembra datos ficticios (admin, 2 funcionarios, médico, socios, especialidades, consultorio). Contraseña ficticia común: `Clave-Segura-1`.
- Firebase y correo externo están desactivados; el enlace de primer ingreso se captura con un listener del evento `PrimerIngresoLinkSolicitado`.

## Ejecución local

```powershell
# PostgreSQL 17 local descartable (ejemplo: puerto 55432)
cd backend\api
$env:E2E_DB_URL = "jdbc:postgresql://localhost:55432/proyecto_e2e"
$env:E2E_DB_USER = "postgres"; $env:E2E_DB_PASSWORD = "postgres"
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

## Hallazgos

- Reservar un número ya tomado devolvía 500 por el índice único parcial `uq_consulta_numero_no_cancelada`; ahora responde 409 `NUMERO_NO_DISPONIBLE` (`ConsultaService`).
- El servidor rechaza con 401 un bearer vencido incluso en `/api/auth/refresh`; por eso el cliente nunca debe enviarlo.

## No cubierto

- Navegador automatizado (Flutter web contra el backend real).
- Docker local (se verifica solo en Actions, workflow Imagen).
- Envío real de correo (Resend) y push Firebase.
- Despliegue en Railway.
