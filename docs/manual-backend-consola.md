# Manual de ejecución del backend en consola (sin frontend)

## 1. Propósito del manual

Este documento explica cómo se construye y se usa el backend real del proyecto sin frontend, desde PowerShell y `curl.exe`, con base en el código y la infraestructura actuales del repositorio.

Se trabaja con la rama `integracion/proyecto-2026-avances` y sin tocar `main`.

## 2. Qué está realmente implementado

### Stack real verificado

- Java 25
- Spring Boot 4.1.1
- Spring Web MVC
- Spring Security
- Spring OAuth2 Resource Server
- PostgreSQL 17 como base de datos objetivo
- JDBC
- JWT (HS256)
- BCrypt para contraseñas
- Firebase Admin para notificaciones push

Evidencia real:

- `backend/api/pom.xml`
- `backend/api/src/main/resources/application.properties`
- `backend/api/src/main/java/uy/edu/proyecto/backend/config/SecurityConfig.java`
- `backend/api/src/main/java/uy/edu/proyecto/backend/config/PasswordConfig.java`
- `database/schema.sql`

### Arquitectura real

La aplicación es un monolito modular con capas bien separadas:

- `auth` → autenticación, refresh, primer ingreso, logout
- `agenda` → disponibilidad y consultas del socio
- `turno` → turnos semanales, fechas, suspensión y rehabilitación
- `aviso` → registro y consulta del aviso de llegada
- `atencion` → registro de resultado de consulta y atención
- `pase` → listado de pases disponibles
- `estadistica` → estadísticas del administrador (RF-39 y RF-40 implementados; RF-41 pendiente)
- `especialidad` / `consultorio` / `usuario` → catálogo y padrón
- `security` → firma y validación JWT
- `config` → seguridad, password, correo y CORS

No es un backend “vacío” ni un prototipo sin estructura: existe una base y servicios reales para los flujos principales del negocio.

## 3. Cómo se inicia el backend

### 3.1. Preparar variables de entorno

En la raíz del repositorio, copiar el ejemplo:

```powershell
Copy-Item .env.example .env
notepad .env
```

Valores mínimos recomendados:

```powershell
DB_URL=jdbc:postgresql://localhost:55432/proyecto_local
DB_USER=proyecto_local
DB_PASSWORD=<contraseña-local-no-productiva>
JWT_SECRET_BASE64=<base64 de 32 bytes o más>
APP_FIREBASE_ENABLED=false
MAIL_PROVIDER=smtp
MAIL_HOST=localhost
MAIL_PORT=1025
CORS_ALLOWED_ORIGIN=http://localhost:5173
COOKIE_SECURE=false
COOKIE_SAME_SITE=Lax
```

El archivo `.env` no se sube al repositorio.

### 3.2. Crear la base PostgreSQL

El backend se conecta a PostgreSQL a través de `spring.datasource` en `application.properties`, y el esquema se crea desde `database/schema.sql`.

Usá una instancia PostgreSQL local dedicada y una base nueva vacía. No apuntes
a `localhost:5432` sin haber comprobado primero qué instancia/base escucha allí.
Este ejemplo supone que ya existe una instancia aislada en el puerto `55432` y
que creaste la base `proyecto_local`; no reutilices datos de producción.

```powershell
psql -h localhost -p 55432 -U proyecto_local -d proyecto_local -f .\database\schema.sql
```

Si el entorno local no tiene `psql`, el requisito sigue siendo el mismo: la base debe existir y debe estar creada con el esquema del proyecto antes de arrancar Spring.

### 3.3. Arrancar la aplicación

```powershell
cd .\backend\api
.\mvnw spring-boot:run
```

La app queda escuchando en:

- `http://localhost:8080`

## 4. Cómo funciona el backend real

### 4.1. Seguridad y JWT

El backend usa `JwtService` para emitir tokens con:

- `issuer = "grupo4-api"`
- `subject = usuarioId`
- claim `role`
- expiración configurable por `app.jwt.expiration-seconds`

La configuración de seguridad está en `SecurityConfig`. La aplicación exige autenticación para rutas protegidas y habilita CORS con `STATELESS` session management.

### 4.2. Login real

El `AuthService` valida:

- CI no vacía
- password no vacía
- acceso `SOCIO` o `EMPLEADO`
- para empleados: `plataforma = WEB`
- usuario y hash con `BCryptPasswordEncoder(12)`

La respuesta del login devuelve un JWT y una cookie de refresh;
la cookie se crea por `RefreshCookieService` y una salida real del backend la entrega en el header `Set-Cookie`.

### 4.3. Base de datos y flujo real

El flujo de la aplicación es:

1. HTTP llega a controller
2. controller delega en servicio
3. servicio consulta repositorios
4. repositorios ejecutan SQL contra PostgreSQL
5. respuesta vuelve por JSON

El esquema de tablas en `database/schema.sql` incluye objetos como:

- `persona`
- `cuenta`
- `sesion`
- `enlace_cuenta`
- `especialidad`
- `consultorio`
- `turno_semanal`
- `numero_semanal`
- `consulta`
- `pase`
- `atencion`
- `aviso_llegada`

Esto es la evidencia real del flujo de negocio hasta PostgreSQL.

## 5. Endpoints reales que existen

A continuación se listan los endpoints implementados y verificados en el código del backend. No se listan rutas inventadas.

### 5.1. Autenticación

Para rutas protegidas, después de autenticar cuentas ficticias de prueba,
copiá el `accessToken` de cada respuesta de login a una variable de entorno
adecuada al rol. No guardes tokens en el repositorio ni los compartas:

```powershell
$base = "http://localhost:8080"
$env:SOCIO_TOKEN = '<accessToken de un socio de prueba>'
$env:FUNCIONARIO_TOKEN = '<accessToken de un funcionario de prueba>'
$env:ADMIN_TOKEN = '<accessToken de un administrador de prueba>'
$env:MEDICO_TOKEN = '<accessToken de un médico de prueba>'
```

#### Login

```powershell
$headers = @{ "Content-Type" = "application/json" }
$body = @{
  ci = "12345678"
  password = "TuPassword123"
  acceso = "SOCIO"
} | ConvertTo-Json

curl.exe -i -c cookies.txt -H "Content-Type: application/json" -d $body http://localhost:8080/api/auth/login
```

Respuesta esperada: JSON con `accessToken` y un refresh token en cookie.

#### Primer ingreso — RF-02

Las dos rutas son públicas (`permitAll`) y no requieren JWT:

- `POST /api/auth/primer-ingreso/solicitar` recibe `ci` y `acceso` (`SOCIO` o
  `EMPLEADO`) y responde `202 Accepted` con el mismo mensaje genérico para
  cuentas inexistentes, pendientes, activas o inactivadas.
- Si faltan campos o la CI/acceso no son válidos, responde `400 VALIDACION`.
- Para una cuenta habilitada que aún no completó el primer ingreso, el backend
  invalida enlaces anteriores, genera un token aleatorio de un solo uso,
  persiste solamente su hash y envía el enlace al correo del padrón. Su
  validez por defecto es 24 horas (`FIRST_LOGIN_TOKEN_VALIDITY_HOURS=24`).
- Si la cuenta ya está activa, se envía un correo que informa que está activa
  y orienta a recuperar la contraseña mediante RF-05. No se crea un enlace de
  activación, no se modifica la cuenta y no se cambia la contraseña.
- Una CI inexistente o una cuenta inactivada no genera correo ni enlace.
  SOCIO y EMPLEADO se resuelven como cuentas independientes.
- `POST /api/auth/primer-ingreso/completar` recibe el token obtenido desde el
  correo, dirección, teléfono 1 y contraseña. Dirección y teléfono son
  obligatorios; la contraseña respeta `PASSWORD_MIN_LENGTH` (8 por defecto).
  El correo no forma parte del DTO de activación. Un token expirado, consumido
  o de una cuenta inactivada devuelve el mismo error `400 ENLACE_INVALIDO`.
  Si falta un dato obligatorio o la contraseña no cumple las reglas responde
  `400 VALIDACION`; una activación válida responde `200 OK`.
- La activación se realiza dentro de una transacción; el enlace se consume en
  PostgreSQL y solo se activa una vez. La contraseña se codifica con el
  `PasswordEncoder` BCrypt configurado por el backend.
- Los correos se procesan de forma asíncrona después del commit. Si el
  proveedor falla, el error no revierte ni deja a medio camino la operación
  de base de datos. Los logs no incluyen el token ni el correo destinatario.

Ejemplo ficticio para solicitar primer ingreso desde PowerShell. La cuenta
debe existir previamente en una base local de pruebas y estar pendiente:

```powershell
$base = "http://localhost:8080"
$solicitud = @{
  ci = "67890127"
  acceso = "SOCIO"
} | ConvertTo-Json

function Invoke-CurlJson {
  param([string]$Uri, [string]$Json)
  $requestFile = [System.IO.Path]::GetTempFileName()
  try {
    [System.IO.File]::WriteAllText(
      $requestFile, $Json, [System.Text.UTF8Encoding]::new($false)
    )
    curl.exe -i -X POST $Uri -H "Content-Type: application/json" `
      --data-binary "@$requestFile"
  } finally {
    Remove-Item -LiteralPath $requestFile -Force
  }
}

# Elegí un solo cliente por solicitud: cada solicitud pendiente invalida
# cualquier enlace de primer ingreso anterior.
$cliente = "powershell"
if ($cliente -eq "powershell") {
  Invoke-RestMethod -Method Post `
    -Uri "$base/api/auth/primer-ingreso/solicitar" `
    -ContentType "application/json" `
    -Body $solicitud
} else {
  Invoke-CurlJson "$base/api/auth/primer-ingreso/solicitar" $solicitud
}
```

La respuesta pública de ambos comandos es genérica. Para completar, obtené el
token desde el correo de prueba (por ejemplo, Mailpit local) y no lo guardes en
archivos, logs ni documentación:

```powershell
$secureToken = Read-Host -Prompt "Token recibido en el correo de prueba" -AsSecureString
$tokenPointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
try {
  $token = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
  $activacion = @{
    token = $token
    direccion = "Av. Ejemplo 123"
    telefono1 = "099123456"
    telefono2 = $null
    password = "Clave-Ficticia-2026"
  } | ConvertTo-Json

  # El enlace es de un solo uso: elegí un solo cliente para esta activación.
  $cliente = "powershell"
  if ($cliente -eq "powershell") {
    Invoke-RestMethod -Method Post `
      -Uri "$base/api/auth/primer-ingreso/completar" `
      -ContentType "application/json" `
      -Body $activacion
  } else {
    Invoke-CurlJson "$base/api/auth/primer-ingreso/completar" $activacion
  }
} finally {
  [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
  Remove-Variable token, activacion, secureToken -ErrorAction SilentlyContinue
}
```

Para probar un correo de cuenta ya activa, enviá la solicitud con una cuenta
ficticia activa. La respuesta HTTP no permite distinguirla de una CI
inexistente; el mensaje de recuperación se verifica únicamente en el buzón de
prueba. El flujo de recuperación completo corresponde a RF-05 y no se
implementa en este cambio de RF-02.

#### Validación de RF-02 en esta revisión

- Pruebas unitarias focalizadas: 15 aprobadas, 0 fallidas, 0 errores y 0
  omitidas (`PrimerIngresoServiceTest` y `PrimerIngresoMailListenerTest`).
- Suite Maven (`./mvnw -B verify`, workflow Backend): 343 aprobadas, 0
  fallidas, 0 errores y 0 omitidas. Son pruebas unitarias, de mocks,
  HTTP/seguridad y de contexto; no incluyen las clases `*IT`, que Maven no
  ejecuta en `verify` (el POM no configura Failsafe).
- Pruebas de integración con PostgreSQL real (workflow `E2E PostgreSQL` de
  GitHub Actions, commit `bc6473d`): 39 IT ejecutadas, 39 aprobadas, 0
  fallidas, 0 errores y 0 omitidas, contra PostgreSQL 17.11. De ellas, 19
  corresponden a `AutenticacionIT` (activación, expiración, reutilización,
  inactivación posterior al enlace, separación SOCIO/EMPLEADO y consumo
  concurrente del mismo enlace). Además se ejecutaron 18 pruebas de contexto
  contra el esquema real.
- La base se ejecutó como servicio efímero del job de GitHub Actions: exclusiva
  del job, descartable, con credenciales ficticias, inicializada con
  `database/schema.sql` y destruida al terminar. No intervienen Railway,
  producción ni una base local.
- Pendiente: E2E con frontend. Tampoco hay una IT que capture el correo
  enviado a una cuenta activa; el contenido del correo se valida con pruebas
  unitarias del listener y la publicación del evento con HTTP.

#### Refresh

```powershell
curl.exe -i -b cookies.txt -c cookies.txt -X POST http://localhost:8080/api/auth/refresh
```

#### Logout

```powershell
curl.exe -i -b cookies.txt -c cookies.txt -X POST http://localhost:8080/api/auth/logout
```

### 5.2. Disponibilidad y agenda del socio

#### Consultar disponibilidad

```powershell
curl.exe -H "Authorization: Bearer $env:SOCIO_TOKEN" "http://localhost:8080/api/disponibilidad?especialidadId=1"
```

#### Agendar consulta

```powershell
$body = @{
  numeroId = 1
  paseId = $null
} | ConvertTo-Json

curl.exe -i -H "Authorization: Bearer $env:SOCIO_TOKEN" -H "Content-Type: application/json" -d $body http://localhost:8080/api/consultas
```

#### Listar consultas del socio

```powershell
curl.exe -H "Authorization: Bearer $env:SOCIO_TOKEN" "http://localhost:8080/api/consultas"
```

#### Detalle de una consulta

```powershell
curl.exe -H "Authorization: Bearer $env:SOCIO_TOKEN" "http://localhost:8080/api/consultas/123"
```

### 5.3. Pases disponibles

```powershell
curl.exe -H "Authorization: Bearer $env:SOCIO_TOKEN" "http://localhost:8080/api/socios/me/pases/disponibles"
```

Este endpoint usa el `sub` del JWT para identificar el socio.

### 5.4. Gestión de turnos y fechas

#### Listar turnos

```powershell
curl.exe -H "Authorization: Bearer $env:FUNCIONARIO_TOKEN" "http://localhost:8080/api/turnos"
```

#### Obtener detalle de turno semanal

```powershell
curl.exe -H "Authorization: Bearer $env:FUNCIONARIO_TOKEN" "http://localhost:8080/api/turnos-semanales/1"
```

#### Suspender fechas

La ruta existe en el servicio. La sintaxis exacta está definida en los request DTOs, no se inventa; debe usarse según el contrato real de los DTOs de turno.

### 5.5. Aviso de llegada

```powershell
curl.exe -H "Authorization: Bearer $env:FUNCIONARIO_TOKEN" "http://localhost:8080/api/avisos-llegada/consultas-hoy?ci=<CI-VALIDA-DE-PRUEBA>"
```

### 5.6. Atención médica

#### Registrar resultado de consulta

```powershell
$body = @{
  afeccion = "Dolor lumbar"
  tratamiento = "Reposo y analgésicos"
  observaciones = "Control en 7 días"
} | ConvertTo-Json

curl.exe -i -H "Authorization: Bearer $env:MEDICO_TOKEN" -H "Content-Type: application/json" -d $body http://localhost:8080/api/medico/consultas/1/resultado
```

### 5.7. Especialidades y consultorios

#### Listar especialidades

```powershell
curl.exe -H "Authorization: Bearer $env:FUNCIONARIO_TOKEN" http://localhost:8080/api/especialidades
```

#### Crear especialidad

```powershell
curl.exe -X POST -H "Authorization: Bearer $env:ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"nombre":"Cardiología","requierePase":true}' http://localhost:8080/api/especialidades
```

#### Listar consultorios

```powershell
curl.exe -H "Authorization: Bearer $env:ADMIN_TOKEN" http://localhost:8080/api/consultorios
```

### 5.8. Contratos verificados para frontend y consola

Los siguientes contratos se contrastaron con los controladores, servicios,
repositorios y `SecurityConfig`. Para todas estas consultas GET se envía:

- `Authorization: Bearer <accessToken>`; el token debe corresponder al rol
  indicado.
- `Accept: application/json`.
- No se requiere `Content-Type` porque no hay cuerpo.

En los ejemplos, las variables `SOCIO_TOKEN`, `FUNCIONARIO_TOKEN` y
`ADMIN_TOKEN` contienen access tokens de cuentas ficticias de pruebas. No
incluyas tokens reales en el historial de PowerShell ni en capturas públicas.

#### `GET /api/medicos`

- **Rol:** `FUNCIONARIO`.
- **Query:** `especialidadId` opcional, entero. Cuando se envía, limita la
  respuesta a médicos habilitados que tienen esa especialidad; cada médico
  conserva en `especialidades` todas las especialidades que tiene asignadas.
- **200:** array de médicos habilitados. Cada elemento contiene `id`, `nombre`,
  `apellido` y `especialidades` (objetos `id`, `nombre`, `requierePase`).
  No incluye CI, correo, teléfonos, contraseñas ni tokens.
- **400:** parámetro mal formado. **401:** sesión ausente/inválida.
  **403:** rol distinto de `FUNCIONARIO`.
- **curl.exe:**

```powershell
curl.exe -i -H "Authorization: Bearer $env:FUNCIONARIO_TOKEN" -H "Accept: application/json" "http://localhost:8080/api/medicos?especialidadId=3"
```

- **Invoke-RestMethod:**

```powershell
Invoke-RestMethod -Method Get -Uri "$base/api/medicos?especialidadId=3" -Headers @{ Authorization = "Bearer $env:FUNCIONARIO_TOKEN"; Accept = "application/json" }
```

Respuesta de ejemplo:

```json
[
  {
    "id": 17,
    "nombre": "Marta",
    "apellido": "Rodriguez",
    "especialidades": [
      { "id": 3, "nombre": "Cardiologia", "requierePase": true }
    ]
  }
]
```

#### `GET /api/usuarios`

- **Rol:** `ADMINISTRADOR`.
- **Query:** `rol` opcional (`SOCIO`, `FUNCIONARIO`, `MEDICO`,
  `ADMINISTRADOR`); `estado` opcional (`ACTIVA`, `INACTIVA`); `texto` opcional
  para coincidencia parcial con CI o apellido; `page` (desde 0, default 0);
  `size` (1-100, default 20).
- **200:** objeto paginado `{items,page,size,total}`. Cada fila es una cuenta e
  incluye `id`, `ci`, `nombre`, `apellido`, `rol`, `correo`, `estado`,
  `activada` y `fechaAlta`. No incluye hashes ni tokens; cuentas inactivas se
  conservan.
- **400:** filtros o paginación inválidos. **401:** sesión ausente/inválida.
  **403:** rol distinto de `ADMINISTRADOR`.
- **curl.exe:**

```powershell
curl.exe -i -H "Authorization: Bearer $env:ADMIN_TOKEN" -H "Accept: application/json" "http://localhost:8080/api/usuarios?rol=SOCIO&estado=ACTIVA&texto=45678911&page=0&size=20"
```

- **Invoke-RestMethod:**

```powershell
Invoke-RestMethod -Method Get -Uri "$base/api/usuarios?rol=SOCIO&estado=ACTIVA&texto=45678911&page=0&size=20" -Headers @{ Authorization = "Bearer $env:ADMIN_TOKEN"; Accept = "application/json" }
```

Respuesta de ejemplo:

```json
{
  "items": [
    {
      "id": 42,
      "ci": "45678911",
      "nombre": "Lucia",
      "apellido": "Fernandez",
      "rol": "SOCIO",
      "correo": "lucia@example.org",
      "estado": "ACTIVA",
      "activada": true,
      "fechaAlta": "2026-09-01T09:00:00-03:00"
    }
  ],
  "page": 0,
  "size": 20,
  "total": 1
}
```

#### `GET /api/historia-clinica`

- **Rol:** `SOCIO`; la identidad y propiedad se determinan por `sub` del JWT.
  No se acepta `socioId`.
- **Query:** `fechaDesde`, `fechaHasta` (`yyyy-MM-dd`); `especialidadId`,
  `medicoId` (enteros positivos); `texto` (coincidencia en tratamiento);
  `orden` (`fecha_atencion` o `especialidad`, default `fecha_atencion`);
  `sentido` (`asc` o `desc`, default `desc`). Los filtros se combinan.
- **200:** array de atenciones propias; cada elemento incluye fecha, médico,
  especialidad, afección, tratamiento, observaciones y `pases` emitidos con
  `emitidoEn` y `venceEl`. La lista no está paginada en esta implementación.
- **400:** formato de fecha, filtro, orden o sentido inválido.
  **401:** sesión ausente/inválida. **403:** rol distinto de `SOCIO`.
- **curl.exe:**

```powershell
curl.exe -i -H "Authorization: Bearer $env:SOCIO_TOKEN" -H "Accept: application/json" "http://localhost:8080/api/historia-clinica?fechaDesde=2026-01-01&fechaHasta=2026-12-31&especialidadId=3&medicoId=17&texto=control&orden=fecha_atencion&sentido=desc"
```

- **Invoke-RestMethod:**

```powershell
Invoke-RestMethod -Method Get -Uri "$base/api/historia-clinica?fechaDesde=2026-01-01&fechaHasta=2026-12-31&especialidadId=3&medicoId=17&texto=control&orden=fecha_atencion&sentido=desc" -Headers @{ Authorization = "Bearer $env:SOCIO_TOKEN"; Accept = "application/json" }
```

Respuesta de ejemplo con datos ficticios:

```json
[
  {
    "idAtencion": 5530,
    "fechaAtencion": "2026-10-20",
    "medicoId": 17,
    "medicoNombre": "Marta",
    "medicoApellido": "Rodriguez",
    "especialidad": { "id": 3, "nombre": "Cardiologia", "requierePase": true },
    "afeccion": "Afeccion ficticia",
    "tratamiento": "Tratamiento ficticio",
    "observaciones": null,
    "pases": [
      {
        "id": 78,
        "especialidad": { "id": 4, "nombre": "Nutricion", "requierePase": true },
        "emitidoEn": "2026-10-20T09:41:00-03:00",
        "venceEl": "2027-01-18"
      }
    ]
  }
]
```

La lista actual expone los datos clínicos solo al socio autenticado y los
devuelve junto con cada atención. Esto difiere de la propuesta de
`contrato-v1.md`, que describía un resumen paginado sin contenido clínico.

#### `GET /api/historia-clinica/{idAtencion}`

- **Rol:** `SOCIO`; se vuelve a verificar la propiedad de la atención en la
  consulta SQL, usando el socio autenticado.
- **Path:** `idAtencion`, entero positivo. No acepta socio como parámetro.
- **200:** mismo objeto de atención que el listado, con afección, tratamiento,
  observaciones y pases con fechas de emisión/vencimiento.
- **400:** ID no positivo. **401:** sesión ausente/inválida.
  **403:** rol distinto de `SOCIO`. **404:** ID inexistente o atención de otro
  socio; ambos casos usan el mismo mensaje sin contenido clínico.
- **curl.exe:**

```powershell
curl.exe -i -H "Authorization: Bearer $env:SOCIO_TOKEN" -H "Accept: application/json" "http://localhost:8080/api/historia-clinica/5530"
```

- **Invoke-RestMethod:**

```powershell
Invoke-RestMethod -Method Get -Uri "$base/api/historia-clinica/5530" -Headers @{ Authorization = "Bearer $env:SOCIO_TOKEN"; Accept = "application/json" }
```

Respuesta de ejemplo con datos ficticios:

```json
{
  "idAtencion": 5530,
  "fechaAtencion": "2026-10-20",
  "medicoId": 17,
  "medicoNombre": "Marta",
  "medicoApellido": "Rodriguez",
  "especialidad": { "id": 3, "nombre": "Cardiologia", "requierePase": true },
  "afeccion": "Afeccion ficticia",
  "tratamiento": "Tratamiento ficticio",
  "observaciones": null,
  "pases": []
}
```

#### `GET /api/consultas`

- **Rol:** `SOCIO`; la identidad se extrae del JWT.
- **Query:** `estado`, `fechaDesde`, `fechaHasta`, `especialidadId`,
  `medicoId`, `orden` (`fecha` o `especialidad`), `sentido` (`asc` o `desc`),
  `page` (default 0) y `size` (default 20, máximo 100). Fechas en
  `yyyy-MM-dd`.
- **200:** objeto `{items,page,size,total}` con consultas propias. Los items
  incluyen `id`, `estado`, fecha/hora, médico, especialidad, consultorio,
  `paseId` y datos de agenda/cancelación.
- **400:** filtro/paginación inválidos. **401:** sesión ausente/inválida.
  **403:** rol distinto de `SOCIO`.
- **curl.exe:**

```powershell
curl.exe -i -H "Authorization: Bearer $env:SOCIO_TOKEN" -H "Accept: application/json" "http://localhost:8080/api/consultas?fechaDesde=2026-10-01&fechaHasta=2026-10-31&page=0&size=20"
```

- **Invoke-RestMethod:**

```powershell
Invoke-RestMethod -Method Get -Uri "$base/api/consultas?fechaDesde=2026-10-01&fechaHasta=2026-10-31&page=0&size=20" -Headers @{ Authorization = "Bearer $env:SOCIO_TOKEN"; Accept = "application/json" }
```

Respuesta resumida:

```json
{
  "items": [
    {
      "id": 9001,
      "estado": "AGENDADA",
      "fecha": "2026-10-20",
      "numero": 2,
      "horaInicio": "09:20",
      "horaFin": "09:40",
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodriguez" },
      "especialidad": { "id": 3, "nombre": "Cardiologia", "requierePase": true },
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2" },
      "paseId": null,
      "agendadaEn": "2026-10-14T10:12:45-03:00",
      "canceladaEn": null,
      "motivoCancelacion": null
    }
  ],
  "page": 0,
  "size": 20,
  "total": 1
}
```

#### `GET /api/agendas`

- **Rol:** `FUNCIONARIO`.
- **Query opcional:** `ci`, `consultaId`, `fecha` (una fecha
  `yyyy-MM-dd`), `medicoId`, `estado`, `llegada` (`true`/`false`), `orden`
  (`fechaHora`/`horaLlegada`), `sentido` (`asc`/`desc`), `page` (default 0)
  y `size` (default 20, máximo 100).
- **200:** `{items,page,size,total}` de agenda operativa; no contiene campos
  de atención clínica.
- **400:** filtros o paginación inválidos. **401:** sesión ausente/inválida.
  **403:** rol distinto de `FUNCIONARIO`.
- **curl.exe:**

```powershell
curl.exe -i -H "Authorization: Bearer $env:FUNCIONARIO_TOKEN" -H "Accept: application/json" "http://localhost:8080/api/agendas?fecha=2026-10-26&llegada=true&page=0&size=20"
```

- **Invoke-RestMethod:**

```powershell
Invoke-RestMethod -Method Get -Uri "$base/api/agendas?fecha=2026-10-26&llegada=true&page=0&size=20" -Headers @{ Authorization = "Bearer $env:FUNCIONARIO_TOKEN"; Accept = "application/json" }
```

Respuesta resumida:

```json
{
  "items": [
    {
      "consultaId": 9001,
      "socio": { "ci": "45678911", "nombre": "Lucia", "apellido": "Fernandez" },
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodriguez" },
      "especialidad": { "id": 3, "nombre": "Cardiologia", "requierePase": true },
      "fecha": "2026-10-26",
      "horaInicio": "09:20",
      "horaFin": "09:40",
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2" },
      "estado": "AGENDADA",
      "llegadaEn": "2026-10-26T08:55:12-03:00"
    }
  ],
  "page": 0,
  "size": 20,
  "total": 1
}
```

#### `GET /api/socios/me/pases/disponibles`

- **Rol:** `SOCIO`; el socio se toma del JWT y no de un parámetro.
- **Query:** ninguno.
- **200:** array de pases propios disponibles, cada uno con `id`,
  `especialidadDestino`, `emitidoEn` y `venceEl`. Lista vacía si no tiene
  pases disponibles.
- **401:** sesión ausente/inválida. **403:** rol distinto de `SOCIO`.
- **curl.exe:**

```powershell
curl.exe -i -H "Authorization: Bearer $env:SOCIO_TOKEN" -H "Accept: application/json" "http://localhost:8080/api/socios/me/pases/disponibles"
```

- **Invoke-RestMethod:**

```powershell
Invoke-RestMethod -Method Get -Uri "$base/api/socios/me/pases/disponibles" -Headers @{ Authorization = "Bearer $env:SOCIO_TOKEN"; Accept = "application/json" }
```

Respuesta de ejemplo:

```json
[
  {
    "id": 78,
    "especialidadDestino": { "id": 4, "nombre": "Nutricion", "requierePase": true },
    "emitidoEn": "2026-10-20T09:41:00-03:00",
    "venceEl": "2027-01-18"
  }
]
```

### 5.9. Estadísticas por especialidad (RF-39)

> Estado: implementado e **integrado en `integracion/proyecto-2026-avances`**
> (PR #24, commit `a22eef9`). **No está desplegado en Railway** (no verificado).
> La ruta es la #34 de `docs/api/endpoints-usados.md`.

#### Arquitectura de estadísticas

Paquete `uy.edu.proyecto.backend.estadistica`, con la misma cadena de capas que
el resto del backend:

| Capa | Clase | Responsabilidad |
|---|---|---|
| Controller | `EstadisticaController` | `GET /api/estadisticas/especialidades`; recibe `desde` y `hasta` como texto. |
| Service | `EstadisticaEspecialidadService` | Interpreta fechas, aplica el mes en curso por defecto, valida el rango y fija los límites en la zona del `Clock` de la aplicación (`America/Montevideo`). |
| Repository | `EstadisticaEspecialidadRepository` | Una consulta SQL parametrizada con `JdbcTemplate`. |
| DTO | `EstadisticaEspecialidadResponse`, `EstadisticaEspecialidadDTO` | Respuesta; reutiliza el record `Especialidad` existente. |
| Seguridad | `SecurityConfig` | `GET /api/estadisticas/**` exige `ROLE_ADMINISTRADOR`. |

RF-40 reutiliza el mismo controller, el mismo `PeriodoEstadistico` (mes en curso, validación y zona horaria) y la misma regla de seguridad (sección 5.10); RF-41 podrá hacerlo igual.

#### Endpoint

`GET /api/estadisticas/especialidades`

- **Rol:** solo `ADMINISTRADOR`. Sin JWT responde 401; `SOCIO`, `FUNCIONARIO` y `MEDICO` reciben 403.
- **Query (opcionales):** `desde` y `hasta`, formato `YYYY-MM-DD`, ambos inclusive.
  Sin parámetros se usa el mes en curso (de su día 1 a su último día). Si falta
  solo uno, se completa con el límite del mes en curso.
- **Qué cuenta:** las consultas **agendadas** en el período, según la fecha en
  que se agendaron (`consulta.agendada_en`), **no** según la fecha de la
  atención. Incluye las consultas que luego se cancelaron (por el socio o por la
  institución). Una misma reserva repetida sobre un número que se liberó cuenta
  como dos reservas.
- **Zona horaria:** `desde` empieza a las 00:00 de Montevideo y `hasta` termina a
  las 24:00 de ese día (límite superior exclusivo en el día siguiente). Una
  reserva hecha el 31/03 a las 23:30 hora local pertenece a marzo aunque en UTC
  ya sea 1/04.
- **200:** `desde`, `hasta` e `items`. Cada item tiene `especialidad`
  (`id`, `nombre`, `requierePase`) y `cantidadConsultas`. Aparecen todas las
  especialidades; las que no tuvieron reservas figuran con `0`. Orden: mayor
  cantidad primero y luego nombre. No se expone ningún dato de socios ni de
  consultas individuales.
- **400** (`code: VALIDACION`): fecha con formato inválido (incluido texto
  malicioso) o `desde` posterior a `hasta`.

Request de ejemplo (curl.exe):

```powershell
curl.exe -i -H "Authorization: Bearer $TOKEN_ADMIN" -H "Accept: application/json" "http://localhost:8080/api/estadisticas/especialidades?desde=2026-03-01&hasta=2026-03-31"
```

PowerShell:

```powershell
$base = "http://localhost:8080"
Invoke-RestMethod -Method Get -Uri "$base/api/estadisticas/especialidades?desde=2026-03-01&hasta=2026-03-31" -Headers @{ Authorization = "Bearer $TOKEN_ADMIN"; Accept = "application/json" }
# Mes en curso:
Invoke-RestMethod -Method Get -Uri "$base/api/estadisticas/especialidades" -Headers @{ Authorization = "Bearer $TOKEN_ADMIN" }
```

Respuesta (datos ficticios):

```json
{
  "desde": "2026-03-01",
  "hasta": "2026-03-31",
  "items": [
    { "especialidad": { "id": 1, "nombre": "Medicina General", "requierePase": false }, "cantidadConsultas": 6 },
    { "especialidad": { "id": 2, "nombre": "Cardiologia", "requierePase": true }, "cantidadConsultas": 2 },
    { "especialidad": { "id": 3, "nombre": "Pediatria", "requierePase": false }, "cantidadConsultas": 0 }
  ]
}
```

#### SQL utilizado y por qué es correcto

```sql
SELECT e.id_especialidad, e.nombre, e.requiere_pase,
       COUNT(x.id_consulta) AS cantidad
FROM public.especialidad e
LEFT JOIN (
    SELECT c.id_consulta, ts.id_especialidad
    FROM public.consulta c
    JOIN public.numero n ON n.id_numero = c.id_numero
    JOIN public.turno t ON t.id_turno = n.id_turno
    JOIN public.turno_semanal ts ON ts.id_turno_semanal = t.id_turno_semanal
    WHERE c.agendada_en >= ? AND c.agendada_en < ?
) x ON x.id_especialidad = e.id_especialidad
GROUP BY e.id_especialidad, e.nombre, e.requiere_pase
ORDER BY cantidad DESC, e.nombre ASC, e.id_especialidad ASC
```

- La especialidad de una consulta se obtiene por `consulta → numero → turno →
  turno_semanal`. Cada consulta tiene un solo número, un solo turno y un solo
  patrón semanal, así que los `JOIN` no duplican filas.
- El filtro del período está únicamente sobre `consulta.agendada_en`. No se
  mira `turno.fecha` (fecha de atención) ni `consulta.estado`, por eso las
  canceladas quedan incluidas.
- El `LEFT JOIN` parte de `especialidad` para mostrar `0` donde no hubo reservas.
- Los dos `?` son `Timestamp` calculados en Java; nunca se concatena texto del
  usuario en el SQL, y las fechas se validan con `LocalDate.parse` antes.

#### Cómo demostrarlo desde consola, sin frontend

1. Levantar una base descartable (nunca la de producción) con `database/schema.sql`
   y el backend contra ella (secciones 3.1 a 3.3).
2. Iniciar sesión como administrador ficticio (`acceso = EMPLEADO`) y guardar el token.
3. Consultar el mes en curso y luego un rango explícito (ejemplos de arriba).
4. Probar los rechazos: sin token (401), con token de socio (403) y con
   `desde=2026-03-31&hasta=2026-03-01` o `desde=ayer` (400).
5. Para mostrar que cuenta por fecha de reserva, comparar contra la base con
   `SELECT count(*) FROM consulta WHERE agendada_en >= '2026-03-01 00:00-03' AND agendada_en < '2026-04-01 00:00-03';`:
   debe coincidir con la suma de `cantidadConsultas`.

#### Pruebas de RF-39

| Tipo | Clase | Cobertura |
|---|---|---|
| Unitaria (Mockito, reloj fijo) | `EstadisticaEspecialidadServiceTest` (8) | mes por defecto, zona Montevideo, límites, rango de un día, rango invertido, formatos inválidos y texto malicioso |
| Mock de JDBC | `EstadisticaEspecialidadRepositoryTest` (1) | SQL por `agendada_en`, sin filtro de estado ni de fecha médica, `LEFT JOIN`, solo dos parámetros, sin datos de pacientes |
| HTTP/seguridad (MockMvc) | `EstadisticaSeguridadTest` (6) | 200 administrador, 403 socio/funcionario/médico, 401 sin JWT, 400, método no permitido |
| Integración PostgreSQL real | `EstadisticaEspecialidadIT` (6) | canceladas incluidas, límites del período, reserva vs. fecha médica, sin duplicados, período vacío, mes en curso, roles, 400 sin alterar la base |

La `EstadisticaEspecialidadIT` solo corre en el workflow `e2e.yml` (PostgreSQL 17
efímero en GitHub Actions). Aprobó 6/6 en CI (ver sección 11).

### 5.10. Estadísticas por turno (RF-40)

> Estado: implementado en la rama `feat/rf-40-estadisticas-turnos`; **no
> integrado en avances ni desplegado**. Ruta #35 de `docs/api/endpoints-usados.md`.

#### Arquitectura

Mismo paquete `estadistica`: `EstadisticaController` (`GET /api/estadisticas/turnos`) →
`EstadisticaTurnoService` → `EstadisticaTurnoRepository` (una consulta SQL
parametrizada) → DTO `EstadisticaTurnoDTO` / `EstadisticaTurnoResponse`.
`PeriodoEstadistico` (compartido con RF-39) resuelve el mes en curso, valida el rango
y usa la zona del `Clock` (`America/Montevideo`). La regla `GET /api/estadisticas/**`
exige `ROLE_ADMINISTRADOR`.

#### Fórmula

```
utilización de un turno = números ocupados / números ofrecidos * 100
```

- **Unidad «turno»:** el patrón semanal (`turno_semanal`: médico, especialidad,
  consultorio y día de la semana) cuya vigencia toca el período.
- **Fechas activas:** fechas (`turno.fecha`) dentro de `[desde, hasta]` (ambos
  inclusive) con `turno.estado = 'ACTIVO'`. Una fecha suspendida queda excluida del
  numerador y del denominador. Una fecha suspendida y luego rehabilitada vuelve a
  `ACTIVO` y cuenta; las consultas que la suspensión canceló siguen canceladas, por
  lo que sus números figuran libres.
- **Ofrecidos:** filas de `numero` de las fechas activas.
- **Ocupado:** el número tiene al menos una consulta que no es `CANCELADA_SOCIO` ni
  `CANCELADA_INSTITUCION`. Eso cubre AGENDADA, ATENDIDA y NO_SE_PRESENTO. NO_ASISTIO y NO_ATENDIDA
  no se guardan en la base: son derivadas de una consulta `AGENDADA` de una fecha ya pasada,
  por lo que también quedan cubiertas.
- **Una vez por número:** se usa `EXISTS`, así que un número cancelado y reservado de nuevo, o con varias
  reservas históricas, suma un único ocupado.
- **Denominador cero:** `utilizacion = "Sin datos"` y `porcentajeUtilizacion = null`.
- **Denominador positivo y ninguna ocupación:** `"0 %"` y `0`.
- Porcentaje con 2 decimales (HALF_UP); en texto se omiten ceros finales (`25 %`, `33.33 %`).

#### Endpoint

`GET /api/estadisticas/turnos?desde=YYYY-MM-DD&hasta=YYYY-MM-DD`

- Rol: solo ADMINISTRADOR (401 sin JWT, 403 para SOCIO, FUNCIONARIO y MEDICO).
- Sin parámetros: mes en curso. 400 `VALIDACION` para formato inválido o `desde` > `hasta`.
- Solo aparecen los patrones cuya vigencia (`fecha_inicio`..`fecha_fin`) toca el período; si
  todas sus fechas del período están suspendidas, figuran con `Sin datos`.
- Orden: nombre de especialidad, día de la semana, id.
- No se expone ningún dato de socios. Se informa el médico (id, nombre y apellido) porque identifica el turno.

Respuesta (datos ficticios; mismos campos que `contrato-v1.md` #35, más `fechasActivas` y `utilizacion`):

```json
{
  "desde": "2026-03-01",
  "hasta": "2026-03-31",
  "items": [
    {
      "turnoSemanalId": 1,
      "medico": { "id": 4, "nombre": "Mario", "apellido": "Medina" },
      "especialidad": { "id": 1, "nombre": "Medicina General", "requierePase": false },
      "consultorio": { "id": 1, "nombre": "Consultorio 1", "ubicacion": "Planta baja" },
      "diaSemana": 1,
      "fechasActivas": 5, "numerosOfrecidos": 17, "numerosOcupados": 9,
      "porcentajeUtilizacion": 52.94, "utilizacion": "52.94 %"
    },
    {
      "turnoSemanalId": 2,
      "medico": { "id": 4, "nombre": "Mario", "apellido": "Medina" },
      "especialidad": { "id": 2, "nombre": "Cardiologia", "requierePase": true },
      "consultorio": { "id": 1, "nombre": "Consultorio 1", "ubicacion": "Planta baja" },
      "diaSemana": 1,
      "fechasActivas": 0, "numerosOfrecidos": 0, "numerosOcupados": 0,
      "porcentajeUtilizacion": null, "utilizacion": "Sin datos"
    }
  ]
}
```

#### SQL utilizado

```sql
SELECT ts.id_turno_semanal, ts.dia_semana, e.id_especialidad, e.nombre, e.requiere_pase,
       ts.id_medico, p.nombre, p.apellido, co.id_consultorio, co.nombre, co.ubicacion,
       COUNT(DISTINCT t.id_turno) AS fechas_activas,
       COUNT(n.id_numero)         AS ofrecidos,
       COALESCE(SUM(CASE WHEN EXISTS (
                SELECT 1 FROM public.consulta c
                WHERE c.id_numero = n.id_numero
                  AND c.estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')
            ) THEN 1 ELSE 0 END), 0) AS ocupados
FROM public.turno_semanal ts
JOIN public.especialidad e ON e.id_especialidad = ts.id_especialidad
JOIN public.cuenta m ON m.id_cuenta = ts.id_medico
JOIN public.persona p ON p.ci = m.ci
JOIN public.consultorio co ON co.id_consultorio = ts.id_consultorio
LEFT JOIN public.turno t ON t.id_turno_semanal = ts.id_turno_semanal
                        AND t.estado = 'ACTIVO' AND t.fecha >= ? AND t.fecha <= ?
LEFT JOIN public.numero n ON n.id_turno = t.id_turno
WHERE ts.fecha_inicio <= ? AND ts.fecha_fin >= ?
GROUP BY ... ORDER BY e.nombre, ts.dia_semana, ts.id_turno_semanal
```

La cadena de `JOIN` es 1:N solo hasta `numero` (una fila por número), y la
reserva se evalúa con `EXISTS`, de modo que no se multiplican filas. El `LEFT JOIN` conserva los
patrones sin fechas activas para poder informar `Sin datos`. Los cuatro `?` son `java.sql.Date`; no se concatena texto del usuario.

#### Limitaciones documentadas

- «Activa» se determina por el estado actual de la fecha (`turno.estado`). `turno_evento` guarda el
  historial de suspensiones y rehabilitaciones, pero no se usa: no hay una regla que haga
  depender el cálculo del momento exacto en que se suspendió una fecha, y no se inventó una.
- Las consultas con `agendada_en` posterior al período también ocupan el número: el RF mide la
  ocupación actual de las fechas del período, no la ocupación en una fecha pasada.
- No se informa un total global ni por especialidad; solo el detalle por turno.

#### Demostración por consola, sin frontend

```powershell
$base = "http://localhost:8080"
$h = @{ Authorization = "Bearer $token"; Accept = "application/json" }
Invoke-RestMethod -Uri "$base/api/estadisticas/turnos?desde=2026-03-01&hasta=2026-03-31" -Headers $h | ConvertTo-Json -Depth 6
Invoke-RestMethod -Uri "$base/api/estadisticas/turnos" -Headers $h   # mes en curso
curl.exe -i -H "Authorization: Bearer $token" "$base/api/estadisticas/turnos?desde=2026-03-01&hasta=2026-03-31"
curl.exe -i "$base/api/estadisticas/turnos"                                 # 401
curl.exe -i -H "Authorization: Bearer $token" "$base/api/estadisticas/turnos?desde=2026-03-31&hasta=2026-03-01"  # 400
```

`$token` es el access token de un administrador ficticio de una base descartable (sección 3).
Para contrastar con SQL: `SELECT count(DISTINCT c.id_numero) FROM consulta c JOIN numero n ON n.id_numero = c.id_numero JOIN turno t ON t.id_turno = n.id_turno WHERE t.id_turno_semanal = 1 AND t.estado = 'ACTIVO' AND t.fecha BETWEEN '2026-03-01' AND '2026-03-31' AND c.estado NOT IN ('CANCELADA_SOCIO','CANCELADA_INSTITUCION');`

#### Pruebas de RF-40

| Tipo | Clase | Cobertura |
|---|---|---|
| Unitaria | `EstadisticaTurnoServiceTest` (7) | mes por defecto, zona Montevideo, rango, fechas inválidas, parcial/total/0 %, Sin datos, redondeo |
| Mock de JDBC | `EstadisticaTurnoRepositoryTest` (1) | solo fechas ACTIVO, EXISTS sobre consultas no canceladas, 4 parámetros, sin datos de pacientes |
| HTTP/seguridad | `EstadisticaSeguridadTest` (+4 de RF-40) | 200 administrador, 403, 401, 400 |
| PostgreSQL real | `EstadisticaTurnoIT` (9) | escenario mixto, estados derivados, reserva repetida, fecha suspendida, rehabilitada, límites, período vacío, roles, SQL injection, sin datos de pacientes, lecturas concurrentes |

`EstadisticaTurnoIT` solo corre en `e2e.yml` (PostgreSQL 17 efímero en GitHub Actions). Resultado confirmado en el PR #25 (commit `ca1af34`, PostgreSQL 17.11): `EstadisticaTurnoIT` 9/9; total IT 54 ejecutadas, 54 aprobadas, 0 fallidas, 0 omitidas; Maven 370 aprobadas.

## 6. Flujo completo hasta PostgreSQL

### Caso típico de login y acceso

1. `POST /api/auth/login` llega a `AuthController`
2. `AuthService.login` valida `ci`, `password`, `acceso` y `plataforma`
3. `CuentaAuthRepository` busca la cuenta por `ci` y rol
4. `PasswordEncoder` compara el password con `BCrypt`
5. `JwtService` genera el access token
6. `RefreshCookieService` arma la cookie de refresh
7. respuesta JSON + header `Set-Cookie`
8. el cliente usa `Authorization: Bearer <token>` para rutas protegidas
9. `SecurityConfig` valida el JWT y decide si el rol puede acceder
10. la operación llega a servicio y repositorio
11. repositorio ejecuta consultas SQL sobre PostgreSQL
12. la base responde con registros
13. el controller serializa JSON

## 7. Qué no se debe asumir

No se debe asumir que:

- todos los RF críticos están totalmente cerrados (ver `docs/informes/estado-backend-grupo4.md`);
- la validación contra PostgreSQL cubre todo: solo las clases `*IT` se ejecutan contra PostgreSQL 17 efímero en GitHub Actions, y nada se validó todavía en un E2E con frontend;
- los tests unitarios son equivalentes a pruebas funcionales sobre el producto final;
- lo que está en una rama de trabajo (por ejemplo RF-40 en su PR) ya está en `integracion/proyecto-2026-avances`, o que algo integrado en avances ya está desplegado en Railway;
- la ruta de especificación solicitada existe en el repositorio.

## 8. Ejemplos útiles para defensa

### Caso 1: login para socio

```powershell
$body = @{ ci = '12345678'; password = 'Secret123'; acceso = 'SOCIO' } | ConvertTo-Json
curl.exe -i -c cookies.txt -H 'Content-Type: application/json' -d $body http://localhost:8080/api/auth/login
```

### Caso 2: login para empleado

```powershell
$body = @{ ci = '12345678'; password = 'Secret123'; acceso = 'EMPLEADO'; plataforma = 'WEB' } | ConvertTo-Json
curl.exe -i -c cookies.txt -H 'Content-Type: application/json' -d $body http://localhost:8080/api/auth/login
```

### Caso 3: consulta de disponibilidad

```powershell
curl.exe -H "Authorization: Bearer $env:SOCIO_TOKEN" "http://localhost:8080/api/disponibilidad?especialidadId=1&orden=fecha&sentido=ASC"
```

### Caso 4: atención médica

```powershell
curl.exe -i -H "Authorization: Bearer $env:MEDICO_TOKEN" -H "Content-Type: application/json" -d '{"afeccion":"Afecci\u00f3n","tratamiento":"Tratamiento","observaciones":"Observaci\u00f3n"}' http://localhost:8080/api/medico/consultas/1/resultado
```

## 9. Recomendaciones operativas

- Mantener `.env` fuera del repositorio.
- No apuntar la app a una base compartida o de producción.
- Usar una base local aislada con `database/schema.sql`.
- Verificar con `curl.exe` antes de ejecutar cualquier flujo de prueba real.
- No correr pruebas destructivas ni sobre datos clínicos reales.
- Tratar los tests unitarios como respaldo de implementación, no como sustituto de validación real de negocio.

## 10. Conclusión

El backend real del repositorio tiene una estructura sólida y un conjunto de endpoints funcionales reales. El manual demuestra cómo levantarlo, autenticarse y operar la API sin frontend. La clave para la defensa es distinguir claramente entre lo que existe en el código y lo que todavía requiere validación real con PostgreSQL y casos de negocio de producción.

## 11. Estado de validación de endpoints críticos

En la revisión del 26/10/2026, antes de RF-02, `.\mvnw.cmd -B verify` terminó
con 338 tests aprobados, 0 fallidos, 0 errores y 0 omitidos, ejecutado con una
URL deliberadamente inalcanzable (`127.0.0.1:1`) para no tocar el listener
local no identificado del puerto 5432. Con RF-02, la suite Maven pasó a 343
aprobadas (0 fallidas, 0 errores, 0 omitidas). Estos resultados corresponden a
pruebas unitarias, de mocks, HTTP/seguridad y de contexto.

Las 39 pruebas de integración `*IT` se ejecutaron en GitHub Actions contra
PostgreSQL 17.11 efímero y aprobaron (ver sección de RF-02). Esa validación cubre
los escenarios implementados en esas clases, entre ellos primer ingreso,
circuito de consultas, roles y concurrencia.

Siguen pendientes en una base PostgreSQL aislada las consultas reales,
paginación/filtros sobre datos de prueba, propiedad de historias clínicas y
vigencia/uso de pases de los endpoints agregados antes de RF-02, salvo que una
`*IT` los cubra expresamente. Sigue pendiente el E2E con frontend. No se usaron
datos clínicos reales.

### RF-39 (PR #24, rama feat/rf-39-estadisticas-especialidad)

En GitHub Actions sobre el commit 528201d: suite Maven 358 aprobadas (343
previas + 15 de RF-39), 0 fallidas, 0 errores, 0 omitidas; 45 IT aprobadas contra
PostgreSQL 17.11 efímero (6 de `EstadisticaEspecialidadIT`), 0 fallidas, 0
omitidas. RF-39 está integrado en avances (`a22eef9`) pero no desplegado en Railway; el E2E
con frontend sigue pendiente.
