# Contrato de la API REST, versión 1 (semanas 1 y 2)

Estado del documento: **PROPUESTA del frontend**, 14/10/2026, rama `docs/contrato-api`. El backend debe confirmar o corregir cada ruta y cada campo. Cuando lo haga, se actualiza `docs/api/endpoints-usados.md` (columna Estado y sección "Cambios de campos") y se anota acá qué cambió.

## 0. Cómo leer este documento

- **Fuentes.** Las operaciones y los DTO salen de `docs/analisis/diseno.md` sección 2.3 y de las secuencias S01 a S25. Las reglas salen de `requerimientos.md` (RF y RNF). Los flujos salen de `casos-de-uso.md`. Las reglas de la API (rutas bajo `/api`, recursos en plural, acciones explícitas de cambio de estado, error uniforme) salen de `arquitectura.md` 7.4, 8.3 y 8.5 y de `diseno.md` 4.5.
- **PROPUESTA.** El Diseño no define ninguna ruta HTTP ni el nombre exacto de cada campo. Por eso **todas las rutas y todos los campos de este documento son PROPUESTA**, salvo los nombres de operación, de DTO y de parámetro que figuran en la tabla de la sección 2 (esos son del Diseño). Donde además se propone una regla o un mecanismo que ningún documento define, aparece la marca **PROPUESTA:** en el texto.
- **Preguntas abiertas.** Lo que ningún documento resuelve está en la sección 9, sin decidir. En cada endpoint se la cita como `P-nn`. Mientras no se resuelvan, el cliente adopta el comportamiento más conservador.
- **Los mockups no se pudieron ver.** Las imágenes de `diseno.md` sección 6 no están en el repositorio (no existe `docs/analisis/media/`). La sección 6 de este contrato relaciona cada pantalla con sus endpoints a partir del título de la pantalla y de los RF que el Diseño dice que cubre, no de la imagen.
- **Sin código.** No hay Java ni Dart. Los ejemplos JSON usan datos ficticios.

## 1. Convenciones

### 1.1 Transporte y formato

| Tema | Convención |
|---|---|
| Base | Todas las rutas cuelgan de `/api`. En web son relativas al mismo origen; en Android se antepone la URL pública HTTPS (RNF-07, arquitectura 7.1.2). |
| Cuerpo | JSON en UTF-8, `Content-Type: application/json`. Campos en `camelCase`. El cliente ignora los campos que no conoce. |
| Autenticación | `Authorization: Bearer <token>` en toda ruta que no sea pública. El token es el JWT de corta duración (15 minutos, arquitectura 8.3). |
| Sesión renovable | El refresh token viaja en una cookie `HttpOnly`, `Secure`, `SameSite=Lax` del mismo origen. Nunca aparece en el cuerpo JSON. |
| Estados de éxito | `200` lectura o acción correcta, `201` alta, `202` solicitud aceptada sin revelar resultado, `204` sin cuerpo. |
| Quién es el usuario | El servidor deduce el socio, el funcionario o el médico del token. **Ningún endpoint recibe `socioId`, `medicoId` ni `funcionarioId` del propio usuario en la ruta ni en el cuerpo** (S06, S23, S13). |
| Autorización | Se verifica en el servidor en cada pedido (RNF-05). Una cuenta inactivada o una sesión revocada recibe `401 NO_AUTENTICADO` en el pedido siguiente. La navegación del cliente según el rol es solo comodidad. |

### 1.2 Fechas, horas y zona horaria

| Tipo | Formato en el JSON | Ejemplo |
|---|---|---|
| Fecha de calendario | ISO 8601 `yyyy-MM-dd` | `"2026-10-20"` |
| Hora del día de un número | `HH:mm` en 24 h, hora de `America/Montevideo` | `"09:30"` |
| Instante (cuándo ocurrió algo) | ISO 8601 con desfase, hora de Uruguay | `"2026-10-14T10:12:45-03:00"` |
| Día de la semana | entero 1 a 7 (1 lunes, 7 domingo), igual que el modelo de datos | `2` |

Los días, los horarios y los vencimientos se interpretan en la hora oficial de Uruguay (RNF-16). "Hoy" es siempre el de Uruguay según el reloj del servidor. El cliente muestra `dd/mm/aaaa` y 24 h (RNF-21); ese formateo es del cliente, el JSON siempre va en ISO.

### 1.3 Paginación

Los listados que el Diseño declara `Page<...>` usan estos parámetros y esta forma de respuesta. La paginación, el filtro y el orden se resuelven en la base (arquitectura 7.4).

| Parámetro | Tipo | Notas |
|---|---|---|
| `page` | entero ≥ 0 | **PROPUESTA:** empieza en 0 (como `Page` de Spring). Por defecto 0. |
| `size` | entero 1 a 100 | **PROPUESTA:** por defecto 20, máximo 100 (P-19). |

```json
{
  "items": [ ],
  "page": 0,
  "size": 20,
  "total": 134
}
```

`total` es la cantidad total de filas que cumplen los filtros, no la de esta página.

Los listados que el Diseño declara `List<...>` (catálogos, disponibilidad, consultas de hoy, estadísticas por especialidad y por turno) responden sin paginación, con esta forma:

```json
{ "items": [ ] }
```

### 1.4 Orden

`orden` es el nombre del campo y `sentido` es `asc` o `desc`. Cada endpoint indica los campos admitidos y el orden por defecto (el que fijan los RF). Un campo de orden desconocido produce `400 VALIDACION`.

### 1.5 Filtros

Los filtros son parámetros de query, opcionales salvo que se indique. Un filtro vacío equivale a no enviarlo. Los filtros de rango (`fechaDesde`, `fechaHasta`) son inclusivos en ambos extremos. Si `fechaDesde` es posterior a `fechaHasta`, `400 VALIDACION`.

### 1.6 Identificadores y nombres

- Una entidad se identifica con `id`. Una referencia a otra entidad se llama `<entidad>Id` (`numeroId`, `paseId`, `especialidadId`, `medicoId`, `consultorioId`), como en las firmas de la sección 2.3 del Diseño.
- Las entidades que el cliente muestra en pantalla viajan anidadas como objeto de referencia (sección 1.8), no como ids sueltos.
- **Excepción heredada:** la respuesta de sesión usa `role` (no `rol`) porque el cliente ya la lee así. En los demás DTO se usa `rol` (P-22).
- CI: **PROPUESTA:** solo dígitos, sin puntos ni guion, con el dígito verificador incluido (ej. `"45678911"`). El cliente normaliza antes de enviar (P-17).
- Valores de enumeración en `MAYÚSCULAS_CON_GUION_BAJO`.

### 1.7 Enumeraciones

| Enumeración | Valores |
|---|---|
| `Rol` | `SOCIO`, `FUNCIONARIO`, `MEDICO`, `ADMINISTRADOR` |
| `TipoAcceso` | `SOCIO`, `EMPLEADO` (el acceso de empleados es solo web, RNF-02) |
| `EstadoConsulta` | Guardados: `AGENDADA`, `ATENDIDA`, `CANCELADA_SOCIO`, `CANCELADA_INSTITUCION`, `NO_SE_PRESENTO`. Calculados al consultar, nunca guardados: `NO_ASISTIO`, `NO_ATENDIDA` (RF-11, diseño 4.2) |
| `EstadoTurno` | `ACTIVO`, `SUSPENDIDO` |
| `EstadoCuenta` | `ACTIVA`, `INACTIVA` (cuenta habilitada o inactivada por un administrador) |
| `SituacionPase` | `DISPONIBLE`, `UTILIZADO`, `VENCIDO` (RF-26; se calcula de su uso y vencimiento, no se guarda) |
| `TipoNotificacion` | `AGENDA`, `CANCELACION`, `SUSPENSION`, `HISTORIA_ACTUALIZADA`, `RECORDATORIO` (modelo de datos, tabla Notificacion) |

`NO_ASISTIO` y `NO_ATENDIDA` solo aparecen para consultas cuyo día ya terminó (24:00 de Uruguay) y que siguen en `AGENDADA` en la base (CU 3.2.3, paso 3).

### 1.8 Objetos de referencia reutilizados

```json
{ "id": 17, "nombre": "Marta", "apellido": "Rodríguez" }
```
`MedicoRef`

```json
{ "id": 3, "nombre": "Cardiología", "requierePase": true }
```
`EspecialidadRef`

```json
{ "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" }
```
`ConsultorioRef`

```json
{ "ci": "45678911", "nombre": "Lucía", "apellido": "Fernández" }
```
`PersonaRef`

### 1.9 `ConsultaDTO` (reutilizado)

`ConsultaDTO` es la forma de una consulta para el socio. Se usa en el alta, en el detalle, en el histórico (`ConsultaHistorialDTO` tiene los mismos campos) y en las consultas de hoy.

```json
{
  "id": 9001,
  "estado": "AGENDADA",
  "fecha": "2026-10-20",
  "numero": 4,
  "horaInicio": "09:30",
  "horaFin": "09:50",
  "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
  "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
  "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
  "paseId": 77,
  "agendadaEn": "2026-10-14T10:12:45-03:00",
  "canceladaEn": null,
  "motivoCancelacion": null
}
```

| Campo | Tipo | Notas |
|---|---|---|
| `id` | entero | Identificador único de la consulta (RF-09). |
| `estado` | `EstadoConsulta` | Puede ser un estado calculado. |
| `fecha`, `horaInicio`, `horaFin` | fecha, hora, hora | De la fecha concreta y del número. |
| `numero` | entero | Número dentro del turno (1, 2, 3...). Identifica la franja; no fija un orden de atención (RF-09). |
| `medico`, `especialidad`, `consultorio` | referencias | Sección 1.8. |
| `paseId` | entero o `null` | Pase usado al agendar. Se conserva aunque la consulta se cancele (diseño 2.2.4). |
| `agendadaEn` | instante | |
| `canceladaEn`, `motivoCancelacion` | instante o `null`, texto o `null` | Solo con estados cancelados. El motivo existe en las cancelaciones institucionales (modelo de datos, `motivo_cancelacion`). |

## 2. Correspondencia con el Diseño 2.3

Los nombres de operación, DTO y parámetro de esta tabla son los del Diseño. El JSON de cada DTO se define en la sección del endpoint.

| # | Endpoint | Operación del Diseño 2.3 | DTO que nombra | Secuencia | RF |
|---|---|---|---|---|---|
| 1 | `POST /api/auth/login` | `AuthService.autenticar(ci, clave, acceso)` | `SesionDTO`, `TokenDTO` | S01 | 01 |
| 2 | `POST /api/auth/refresh` | `AuthService` (renovación, arquitectura 8.3) | `SesionDTO` | S01 | 01 |
| 3 | `POST /api/auth/logout` | `AuthService` (cierre, arquitectura 8.3) | - | - | 03 |
| 4 | `POST /api/auth/primer-ingreso/solicitar` | `ActivacionService.solicitar(ci, acceso)` | `SolicitudAceptadaDTO` | S02 | 02 |
| 5 | `POST /api/auth/primer-ingreso/completar` | `ActivacionService.activar(token, datos, clave)` | `DatosActivacionDTO`, `CuentaDTO` | S02 | 02 |
| 6 | `GET /api/especialidades` | listado de catálogo (sin operación en 2.3) | `EspecialidadDTO` | - | 29, 13, 08, 31 |
| 7 | `POST /api/especialidades` | `EspecialidadService.crear(nombre, requierePase)` | `EspecialidadDTO` | S16 | 29 |
| 8 | `GET /api/consultorios` | listado de catálogo (sin operación en 2.3) | `ConsultorioDTO` | - | 33, 13 |
| 9 | `POST /api/consultorios` | `ConsultorioService.crear(datos)` | `AltaConsultorioDTO`, `ConsultorioDTO` | S18 | 33 |
| 10 | `GET /api/medicos` | listado de apoyo (sin operación en 2.3) | - | - | 13, 08, 14, 15, 17, 18 |
| 11 | `POST /api/usuarios` | `UsuarioService.crearUsuarioPendiente(datos)` | `AltaUsuarioDTO`, `CuentaDTO` | S17 | 31 |
| 12 | `GET /api/usuarios` | `UsuarioService.consultarPadron(filtros)` | `FiltroUsuariosDTO`, `UsuarioDTO` | S19 | 35 |
| 13 | `POST /api/turnos-semanales` | `TurnoService.crearTurnoSemanal(datos)` | `AltaTurnoDTO`, `TurnoSemanalDTO` | S07 | 13 |
| 14 | `GET /api/turnos-semanales/{id}` | consulta de la configuración (S11, RF-17) | `TurnoSemanalDTO` | S11 | 17 |
| 15 | `GET /api/turnos` | `TurnoService.consultarTurnos(filtros)` | `FiltroTurnosDTO`, `TurnoDTO` | S11 | 17 |
| 16 | `GET /api/disponibilidad` | `AgendaService.consultarDisponibilidad(filtros)` | `FiltroDisponibilidadDTO`, `NumeroDisponibleDTO` | S03 | 08 |
| 17 | `POST /api/consultas` | `AgendaService.agendar(socioId, numeroId, paseId?)` | `ConsultaDTO` | S04 | 09 |
| 18 | `GET /api/consultas` | `AgendaService.consultarHistorial(socioId, filtros)` | `FiltroHistorialDTO`, `ConsultaHistorialDTO` | S05 | 11 |
| 19 | `GET /api/consultas/{id}` | detalle de una consulta (RF-11) | `ConsultaHistorialDTO` | S05 | 11 |
| 20 | `POST /api/consultas/{id}/cancelar` | `CancelacionService.cancelarPorSocio(socioId, consultaId)` | `CancelacionDTO` | S23 | 10 |
| 21 | `GET /api/historia-clinica` | `ConsultaService.obtenerHistoria(socioId, filtros)` | `FiltroHistoriaDTO`, `HistoriaDTO`, `AtencionDTO` | S06 | 12 |
| 22 | `GET /api/historia-clinica/{idAtencion}` | detalle de una atención (RF-12) | `AtencionDTO`, `PaseDTO` | S06 | 12 |
| 23 | `POST /api/turnos/suspensiones/previsualizar` | previa de `TurnoService.suspenderFechas` (S08) | `FiltroFechasDTO` | S08 | 14 |
| 24 | `POST /api/turnos/suspensiones` | `TurnoService.suspenderFechas(filtro, ids)` | `FiltroFechasDTO`, `ResultadoFechasDTO` | S08 | 14 |
| 25 | `POST /api/turnos/rehabilitaciones` | `TurnoService.rehabilitarFechas(filtro, ids)` | `FiltroFechasDTO`, `ResultadoFechasDTO` | S09 | 15 |
| 26 | `GET /api/avisos-llegada/consultas-hoy` | `ConsultaService.obtenerConsultasHoy(ci)` | `ConsultaDTO` | S10 | 16 |
| 27 | `POST /api/avisos-llegada` | `LlegadaService.registrarAviso(ci, funcionarioId, fecha)` | `AvisoLlegadaDTO` | S10 | 16 |
| 28 | `GET /api/agendas` | `AgendaService.consultarAgendas(filtros)` | `FiltroAgendaDTO`, `AgendaOperativaDTO` | S12 | 18 |
| 29 | `GET /api/medico/turnos` | `TurnoService.consultarTurnosDelMedico(medicoId, fecha)` | `TurnosPacientesDTO` | S13 | 21 |
| 30 | `GET /api/medico/turnos/{id}/numeros` | ídem (detalle de un turno) | `TurnosPacientesDTO` | S13 | 21 |
| 31 | `POST /api/medico/consultas/{id}/resultado` | `AtencionService.registrarResultado(medicoId, consultaId, datos)` y `PaseService.validarYCrearEnAtencion(atencionId, solicitudes)` | `ResultadoConsultaDTO`, `PaseNuevoDTO`, `PaseDTO` | S14, S15 | 23, 24 |
| 32 | `GET /api/notificaciones` | listado de avisos internos (sin operación de lectura en 2.3) | - | - | RNF-24 |
| 33 | `POST /api/dispositivos` | registro de destino push (sin operación en 2.3) | - | - | RNF-24 |
| 34 | `GET /api/estadisticas/especialidades` | `EstadisticaService.calcularPorEspecialidad(filtro)` | `FiltroEstadisticaDTO`, `EstadisticaEspecialidadDTO` | S20 | 39 |
| 35 | `GET /api/estadisticas/turnos` | `EstadisticaService.calcularPorTurno(filtro)` | `FiltroEstadisticaDTO`, `EstadisticaTurnoDTO` | S21 | 40 |
| 36 | `GET /api/estadisticas/consultas` | `EstadisticaService.calcularConsultas(filtro)` | `FiltroEstadisticaDTO`, `EstadisticaConsultaDTO` | S22 | 41 |

La numeración `#1` a `#36` es la de `docs/api/endpoints-usados.md`.

---

## 3. Endpoints

Cada endpoint indica: roles, RF, operación del Diseño, parámetros, respuesta con ejemplo y errores. Todos los errores usan la forma de la sección 5. **Los errores `400 VALIDACION`, `401 NO_AUTENTICADO` y `403 SIN_PERMISO` aplican a todo endpoint protegido y no se repiten en cada tabla**, salvo que tengan un significado particular. Un `500 ERROR_INTERNO` puede ocurrir en cualquiera.

### 3.1 Sesión y primer ingreso

<a id="e01"></a>
#### #1 · `POST /api/auth/login`

- **Roles:** público.
- **RF:** RF-01. **Diseño:** `autenticar(ci, clave, acceso): SesionDTO` (S01). **Estado:** PROPUESTA.

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `ci` | texto | sí | Sección 1.6. |
| `password` | texto | sí | Es la `clave` de la firma del Diseño. |
| `acceso` | `TipoAcceso` | sí | `SOCIO` desde el acceso de socios (web y Android); `EMPLEADO` desde el acceso de empleados (solo web). |

```json
{ "ci": "45678911", "password": "claveSegura1", "acceso": "SOCIO" }
```

**Qué se devuelve y cuándo.** Responde `200` solo si se cumplen **todas** estas condiciones: existe una cuenta para esa CI **en ese acceso**, la contraseña coincide, la cuenta está habilitada y completó el primer ingreso. En cualquier otro caso responde **siempre la misma respuesta**, el mismo `401 CREDENCIALES_INVALIDAS` con el mismo mensaje: CI inexistente, contraseña incorrecta, cuenta inactivada, cuenta pendiente de primer ingreso, o CI de empleado probada en el acceso de socios (y al revés). El rol de la sesión lo fija la cuenta, no la pantalla (S01). El cliente no puede deducir cuál de los datos falló ni si la cuenta existe (RF-01, RNF-10).

**Respuesta 200** (`SesionDTO`, con el `TokenDTO` de `emitirJWT` aplanado)

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI0MiJ9.firma-de-ejemplo",
  "role": "SOCIO",
  "nombre": "Lucía",
  "apellido": "Fernández"
}
```

Además, en la misma respuesta: `Set-Cookie: <refresh>; HttpOnly; Secure; SameSite=Lax; Path=/api/auth`. **PROPUESTA:** el nombre de la cookie y su `Path` los define el backend; el cliente no los lee.

Con `acceso: "SOCIO"`, `role` es `SOCIO`. Con `acceso: "EMPLEADO"`, `role` es `FUNCIONARIO`, `MEDICO` o `ADMINISTRADOR`.

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | Falta un campo, o `acceso` no es `SOCIO` ni `EMPLEADO`. Solo por forma del pedido, nunca por el contenido de las credenciales. |
| 401 | `CREDENCIALES_INVALIDAS` | Cualquier otro motivo de rechazo, sin distinguirlos. Mensaje: "La cédula o la contraseña no son correctas. Revisá los datos e intentá de nuevo." |

Preguntas relacionadas: P-02, P-03, P-21.

<a id="e02"></a>
#### #2 · `POST /api/auth/refresh`

- **Roles:** público; autentica con la cookie de renovación, sin `Authorization`.
- **RF:** RF-01, RNF-08. **Diseño:** arquitectura 8.3. **Estado:** PROPUESTA.

Sin cuerpo. Rota el refresh: invalida el anterior y emite otro en la cookie. **PROPUESTA:** devuelve la misma forma que el login para que el cliente pueda reconstruir la sesión en memoria al recargar la web (el access token vive solo en memoria).

**Respuesta 200**

```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI0MiJ9.otra-firma-de-ejemplo",
  "role": "SOCIO",
  "nombre": "Lucía",
  "apellido": "Fernández"
}
```

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 401 | `SESION_INVALIDA` | No hay cookie, está vencida o revocada, o la cuenta fue inactivada. El cliente descarta sus credenciales y vuelve al login. |
| 403 | `CSRF_INVALIDO` | Falla la protección CSRF que arquitectura 8.3 exige para operaciones autenticadas por cookie (P-02). |

<a id="e03"></a>
#### #3 · `POST /api/auth/logout`

- **Roles:** cualquier rol autenticado.
- **RF:** RF-03, RNF-08. **Diseño:** arquitectura 8.3. **Estado:** PROPUESTA.

Sin cuerpo. Revoca la sesión en el servidor y borra la cookie de renovación. El cliente descarta su token.

**Respuesta 204**, sin cuerpo.

**Errores:** `401 NO_AUTENTICADO` si el token ya no es válido (el cliente igual descarta sus credenciales). `403 CSRF_INVALIDO` (P-02).

<a id="e04"></a>
#### #4 · `POST /api/auth/primer-ingreso/solicitar`

- **Roles:** público.
- **RF:** RF-02. **Diseño:** `solicitar(ci, acceso): SolicitudAceptadaDTO` (S02). **Estado:** PROPUESTA.

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `ci` | texto | sí | |
| `acceso` | `TipoAcceso` | sí | El sistema identifica la cuenta según el acceso usado. |

```json
{ "ci": "45678911", "acceso": "SOCIO" }
```

**Respuesta 202.** Siempre el mismo cuerpo, exista o no la CI, esté la cuenta pendiente, activa o inactivada (RF-02, S02). El texto es el que fija el CU 3.1.2, paso 5.

```json
{
  "message": "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones."
}
```

Lo que pase después (enviar el enlace de un solo uso válido por 24 horas, enviar el correo de "ya está activa" o no enviar nada) es interno y asíncrono; no cambia la respuesta ni su tiempo apreciable. No se puede enumerar CI con este endpoint.

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | Falta un campo o `acceso` inválido. Solo por forma del pedido; nunca depende de si la CI existe. |

<a id="e05"></a>
#### #5 · `POST /api/auth/primer-ingreso/completar`

- **Roles:** público; autoriza con el `token` del enlace.
- **RF:** RF-02. **Diseño:** `activar(token, datos: DatosActivacionDTO, clave): CuentaDTO` (S02). **Estado:** PROPUESTA.

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `token` | texto | sí | El del enlace recibido por correo. De un solo uso, válido 24 horas. |
| `direccion` | texto | sí | Obligatoria al completar el primer ingreso (RF-02). |
| `telefono1` | texto | sí | RF-02 exige al menos un teléfono. |
| `telefono2` | texto | no | |
| `password` | texto | sí | Mínimo 8 caracteres (parámetro configurable, 3.1.3). |

El correo **no** se envía ni se puede modificar en el primer ingreso (RF-02).

```json
{
  "token": "b7f3c1d0a9e84f2c8b1d6e5f4a3b2c1d",
  "direccion": "Av. 18 de Julio 1234, Montevideo",
  "telefono1": "099123456",
  "telefono2": null,
  "password": "claveSegura1"
}
```

**Respuesta 200** (`CuentaDTO`)

```json
{
  "id": 42,
  "ci": "45678911",
  "nombre": "Lucía",
  "apellido": "Fernández",
  "rol": "SOCIO",
  "estado": "ACTIVA",
  "activada": true
}
```

La cuenta queda activa y el usuario inicia sesión por #1. No devuelve token: no inicia sesión sola.

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | Falta un campo o la contraseña no cumple la longitud mínima. |
| 400 | `ENLACE_INVALIDO` | El enlace no existe, venció, ya se usó, o la cuenta fue inactivada por un administrador. **Mismo código y mismo mensaje en los cuatro casos** (el primer ingreso no revierte una inactivación, RF-02). Mensaje: "El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso." |

Preguntas relacionadas: P-04.

### 3.2 Catálogos de apoyo

<a id="e06"></a>
#### #6 · `GET /api/especialidades`

- **Roles:** cualquier rol autenticado.
- **RF:** RF-29 (catálogo), y los formularios de RF-08, RF-13, RF-14, RF-17, RF-24 y RF-31. **Diseño:** `EspecialidadDTO`. **Estado:** PROPUESTA.

Sin parámetros. Devuelve todas las especialidades, sin paginar, ordenadas por `nombre`. Los filtros y el orden de RF-36 (consulta de especialidades por el administrador) no están en este contrato.

**Respuesta 200**

```json
{
  "items": [
    { "id": 1, "nombre": "Medicina General", "requierePase": false },
    { "id": 3, "nombre": "Cardiología", "requierePase": true }
  ]
}
```

<a id="e07"></a>
#### #7 · `POST /api/especialidades`

- **Roles:** ADMINISTRADOR.
- **RF:** RF-29. **Diseño:** `crear(nombre, requierePase): EspecialidadDTO` (S16). **Estado:** PROPUESTA.

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `nombre` | texto, hasta 120 | sí | Único sin distinguir mayúsculas. |
| `requierePase` | booleano | sí | |

```json
{ "nombre": "Neurología", "requierePase": true }
```

**Respuesta 201**

```json
{ "id": 9, "nombre": "Neurología", "requierePase": true }
```

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 409 | `ESPECIALIDAD_DUPLICADA` | Ya hay una con ese nombre, también si dos altas simultáneas chocan en el índice único (S16). Mensaje: "Ya existe una especialidad registrada con ese nombre." |

<a id="e08"></a>
#### #8 · `GET /api/consultorios`

- **Roles:** cualquier rol autenticado.
- **RF:** RF-33 (catálogo) y el formulario de RF-13. **Diseño:** `ConsultorioDTO`. **Estado:** PROPUESTA.

Sin parámetros. Todos los consultorios, sin paginar, ordenados por `nombre`. Los filtros de RF-37 no están en este contrato.

**Respuesta 200**

```json
{
  "items": [
    { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
    { "id": 6, "nombre": "Consultorio 6", "ubicacion": "Piso 2, ala sur" }
  ]
}
```

<a id="e09"></a>
#### #9 · `POST /api/consultorios`

- **Roles:** ADMINISTRADOR.
- **RF:** RF-33. **Diseño:** `crear(datos: AltaConsultorioDTO): ConsultorioDTO` (S18). **Estado:** PROPUESTA.

**Cuerpo** (`AltaConsultorioDTO`)

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `nombre` | texto, hasta 120 | sí | Nombre o número; único (normalizado). |
| `ubicacion` | texto, hasta 200 | sí | Piso o sector (RF-33). |

```json
{ "nombre": "Consultorio 7", "ubicacion": "Piso 3" }
```

**Respuesta 201** (`ConsultorioDTO`)

```json
{ "id": 7, "nombre": "Consultorio 7", "ubicacion": "Piso 3" }
```

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 409 | `CONSULTORIO_DUPLICADO` | El nombre o número ya existe (también ante altas simultáneas, S18). |

<a id="e10"></a>
#### #10 · `GET /api/medicos`

- **Roles:** cualquier rol autenticado.
- **RF:** RF-13, RF-08, RF-14, RF-15, RF-17, RF-18 (selectores de médico). **Diseño:** sin operación en 2.3. **Estado:** PROPUESTA.

| Parámetro | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `especialidadId` | entero | no | Si se envía, solo médicos que ejercen esa especialidad. |

Devuelve médicos **activos**, sin paginar, ordenados por `apellido` y `nombre`. Cada médico trae sus especialidades, porque el alta de turno exige "una de las del médico" (RF-13). No expone CI, correo ni teléfonos.

**Respuesta 200**

```json
{
  "items": [
    {
      "id": 17,
      "nombre": "Marta",
      "apellido": "Rodríguez",
      "especialidades": [
        { "id": 1, "nombre": "Medicina General", "requierePase": false },
        { "id": 3, "nombre": "Cardiología", "requierePase": true }
      ]
    }
  ]
}
```

Preguntas relacionadas: P-16.

### 3.3 Administración de usuarios

<a id="e11"></a>
#### #11 · `POST /api/usuarios`

- **Roles:** ADMINISTRADOR.
- **RF:** RF-31. **Diseño:** `crearUsuarioPendiente(datos: AltaUsuarioDTO): CuentaDTO` (S17). **Estado:** PROPUESTA.

Registra la persona en el padrón y deja la cuenta **pendiente de primer ingreso**. **No envía ningún correo** (RF-31, S17). El envío ocurre cuando el titular lo pide por #4.

**Cuerpo** (`AltaUsuarioDTO`)

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `ci` | texto | sí | Con dígito verificador válido. |
| `nombre` | texto | sí | |
| `apellido` | texto | sí | |
| `fechaNacimiento` | fecha | sí | |
| `correo` | texto | sí | Puede repetirse entre personas. |
| `telefono1` | texto | sí | |
| `telefono2` | texto | no | |
| `direccion` | texto | no | Opcional en el alta (RF-31). |
| `rol` | `Rol` | sí | |
| `especialidadIds` | lista de enteros | solo si `rol` es `MEDICO` | Una o más especialidades existentes. Para los demás roles debe omitirse o ir vacía. |

```json
{
  "ci": "67890127",
  "nombre": "Marta",
  "apellido": "Rodríguez",
  "fechaNacimiento": "1978-03-15",
  "correo": "marta.rodriguez@example.org",
  "telefono1": "099111222",
  "telefono2": null,
  "direccion": null,
  "rol": "MEDICO",
  "especialidadIds": [1, 3]
}
```

**Respuesta 201** (`CuentaDTO`)

```json
{
  "id": 17,
  "ci": "67890127",
  "nombre": "Marta",
  "apellido": "Rodríguez",
  "rol": "MEDICO",
  "estado": "ACTIVA",
  "activada": false
}
```

`estado: "ACTIVA"` con `activada: false` es una cuenta habilitada que todavía no completó el primer ingreso. No es lo mismo que `INACTIVA` (inactivada por un administrador).

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `CI_INVALIDA` | El dígito verificador no corresponde. |
| 400 | `VALIDACION` | Falta un campo, el correo no tiene forma válida, `especialidadIds` falta con rol `MEDICO` o viene con otro rol, o alguna especialidad no existe. |
| 409 | `DATOS_PERSONA_DISCORDANTES` | La CI ya existe y el nombre, el apellido o la fecha de nacimiento no coinciden. El administrador debe corregir primero el dato (RF-38, fuera de este contrato). |
| 409 | `SOCIO_DUPLICADO` | La CI ya tiene cuenta de socio. |
| 409 | `EMPLEADO_DUPLICADO` | La CI ya tiene una cuenta de empleado habilitada o pendiente que no fue inactivada. |

<a id="e12"></a>
#### #12 · `GET /api/usuarios`

- **Roles:** ADMINISTRADOR.
- **RF:** RF-35. **Diseño:** `consultarPadron(filtros: FiltroUsuariosDTO): Page<UsuarioDTO>` (S19). **Estado:** PROPUESTA.

Una fila por cuenta. Una persona con varias cuentas (incluidas las de empleado anteriores inactivadas) aparece una vez por cada una.

| Parámetro | Tipo | Notas |
|---|---|---|
| `rol` | `Rol` | |
| `estado` | `EstadoCuenta` | `ACTIVA` o `INACTIVA`. |
| `q` | texto | **PROPUESTA:** coincidencia parcial, sin distinguir mayúsculas, con CI o apellido. |
| `orden` | `apellido` o `fechaAlta` | Por defecto `apellido`. |
| `sentido` | `asc` o `desc` | Por defecto `asc`. |
| `page`, `size` | | Sección 1.3. |

**Respuesta 200** (`UsuarioDTO`)

```json
{
  "items": [
    {
      "id": 42,
      "ci": "45678911",
      "nombre": "Lucía",
      "apellido": "Fernández",
      "rol": "SOCIO",
      "correo": "lucia.fernandez@example.org",
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

La respuesta **nunca** incluye hashes de contraseña, tokens ni enlaces de activación (S19).

### 3.4 Turnos (funcionario)

<a id="e13"></a>
#### #13 · `POST /api/turnos-semanales`

- **Roles:** FUNCIONARIO.
- **RF:** RF-13. **Diseño:** `crearTurnoSemanal(datos: AltaTurnoDTO): TurnoSemanalDTO` (S07). **Estado:** PROPUESTA.

Crea el patrón, sus números y un turno concreto por cada fecha del día elegido dentro de la vigencia, todo en una transacción (diseño 4.1).

**Cuerpo** (`AltaTurnoDTO`)

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `medicoId` | entero | sí | Médico activo. |
| `especialidadId` | entero | sí | Una de las del médico. |
| `consultorioId` | entero | sí | |
| `diaSemana` | entero 1 a 7 | sí | 1 lunes. |
| `fechaInicio` | fecha | sí | |
| `fechaFin` | fecha | sí | Mayor o igual a `fechaInicio`. |
| `numeros` | lista | sí | Al menos 1 (cupo mínimo, RF-13). |
| `numeros[].numero` | entero ≥ 1 | sí | **PROPUESTA:** lo envía el cliente (1, 2, 3...). Único dentro de la lista. |
| `numeros[].horaInicio` | hora | sí | Múltiplo de 5 minutos. |
| `numeros[].horaFin` | hora | sí | Múltiplo de 5 minutos; duración de 10 a 60 minutos (3.1.3). |

Puede haber huecos entre números; los números no se solapan entre sí.

```json
{
  "medicoId": 17,
  "especialidadId": 3,
  "consultorioId": 5,
  "diaSemana": 2,
  "fechaInicio": "2026-10-20",
  "fechaFin": "2026-12-15",
  "numeros": [
    { "numero": 1, "horaInicio": "09:00", "horaFin": "09:20" },
    { "numero": 2, "horaInicio": "09:20", "horaFin": "09:40" },
    { "numero": 3, "horaInicio": "10:00", "horaFin": "10:30" }
  ]
}
```

**Respuesta 201** (`TurnoSemanalDTO`)

```json
{
  "id": 120,
  "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
  "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
  "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
  "diaSemana": 2,
  "fechaInicio": "2026-10-20",
  "fechaFin": "2026-12-15",
  "numeros": [
    { "numero": 1, "horaInicio": "09:00", "horaFin": "09:20" },
    { "numero": 2, "horaInicio": "09:20", "horaFin": "09:40" },
    { "numero": 3, "horaInicio": "10:00", "horaFin": "10:30" }
  ],
  "cantidadTurnos": 9
}
```

`cantidadTurnos` (**PROPUESTA**) es la cantidad de turnos concretos generados, para el mensaje de confirmación.

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | Falta un dato, `fechaFin` anterior a `fechaInicio`, cupo menor que 1, duración fuera de 10 a 60, horas que no son múltiplo de 5, números repetidos o solapados entre sí. |
| 400 | `ESPECIALIDAD_NO_DEL_MEDICO` | La especialidad no es una de las del médico. |
| 404 | `NO_ENCONTRADO` | `medicoId` o `consultorioId` no existen. |
| 409 | `MEDICO_INACTIVO` | El médico no está activo. |
| 409 | `SOLAPAMIENTO_TURNO` | Algún número se solapa, en alguna fecha activa de la vigencia, con un turno activo del mismo médico o del mismo consultorio. No se crea nada (S07). El mensaje debe nombrar las fechas y números en conflicto (CU 3.3.1, 7.A.2); ver P-01. |

<a id="e14"></a>
#### #14 · `GET /api/turnos-semanales/{id}`

- **Roles:** FUNCIONARIO.
- **RF:** RF-17 ("permite consultar la configuración semanal y sus fechas de inicio y finalización"). **Diseño:** S11. **Estado:** PROPUESTA.

Devuelve el `TurnoSemanalDTO` de #13, tal cual. Sin parámetros.

**Respuesta 200**: la misma forma que la respuesta de #13. `cantidadTurnos` es la cantidad de fechas concretas que tiene el patrón (**PROPUESTA**).

**Errores:** `404 NO_ENCONTRADO` si el id no existe.

<a id="e15"></a>
#### #15 · `GET /api/turnos`

- **Roles:** FUNCIONARIO.
- **RF:** RF-17; sirve de selección para RF-14 y RF-15. **Diseño:** `consultarTurnos(filtros: FiltroTurnosDTO): Page<TurnoDTO>` (S11). **Estado:** PROPUESTA.

Devuelve **fechas concretas** de turnos (no patrones; para el patrón se usa #14).

| Parámetro | Tipo | Notas |
|---|---|---|
| `medicoId` | entero | |
| `especialidadId` | entero | |
| `diaSemana` | entero 1 a 7 | |
| `fechaDesde`, `fechaHasta` | fecha | Rango de fechas. |
| `estado` | `EstadoTurno` | `ACTIVO` o `SUSPENDIDO`. |
| `orden` | `fecha`, `medico`, `especialidad` | Por defecto `fecha` (fecha y luego horario, RF-17). |
| `sentido` | `asc` o `desc` | Por defecto `asc`. |
| `page`, `size` | | Sección 1.3. |

**Respuesta 200** (`TurnoDTO`)

```json
{
  "items": [
    {
      "id": 301,
      "turnoSemanalId": 120,
      "fecha": "2026-10-20",
      "diaSemana": 2,
      "horaInicio": "09:00",
      "horaFin": "10:30",
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
      "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
      "cantidadNumeros": 3,
      "estado": "ACTIVO"
    }
  ],
  "page": 0,
  "size": 20,
  "total": 9
}
```

`horaInicio` y `horaFin` (**PROPUESTA**) son el inicio del primer número y el fin del último: el "horario" que pide RF-17.

### 3.5 Socio: disponibilidad, agenda e histórico

<a id="e16"></a>
#### #16 · `GET /api/disponibilidad`

- **Roles:** SOCIO.
- **RF:** RF-08. **Diseño:** `consultarDisponibilidad(filtros: FiltroDisponibilidadDTO): List<NumeroDisponibleDTO>` (S03). **Estado:** PROPUESTA.

Solo números que todavía pueden agendarse (anticipación máxima y mínima) y que no son de fechas suspendidas. Es informativo: no bloquea números, y al confirmar se vuelve a comprobar todo (S03).

| Parámetro | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `especialidadId` | entero | **sí** | |
| `medicoId` | entero | no | |
| `fechaDesde`, `fechaHasta` | fecha | no | |
| `orden` | `fecha` o `apellidoMedico` | no | Por defecto `fecha` (fecha y hora más próximas). |
| `sentido` | `asc` o `desc` | no | Por defecto `asc`. |

**Respuesta 200** (`NumeroDisponibleDTO`; sin paginar, como declara el Diseño: P-11)

```json
{
  "items": [
    {
      "numeroId": 4501,
      "turnoId": 301,
      "numero": 2,
      "fecha": "2026-10-20",
      "horaInicio": "09:20",
      "horaFin": "09:40",
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
      "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" }
    }
  ]
}
```

`especialidad.requierePase` es la indicación que RF-08 exige mostrar. Si no hay resultados, `{ "items": [] }` con `200` (el cliente muestra "No se encontraron turnos disponibles para los criterios seleccionados", CU 3.2.1).

**Errores:** `400 VALIDACION` si falta `especialidadId` o el rango está invertido. `404 NO_ENCONTRADO` si `especialidadId` o `medicoId` no existen.

<a id="e17"></a>
#### #17 · `POST /api/consultas`

- **Roles:** SOCIO.
- **RF:** RF-09. **Diseño:** `agendar(socioId, numeroId, paseId?): ConsultaDTO` (S04). **Estado:** PROPUESTA.

El `socioId` sale del token. Toda la validación y la inserción ocurren en una transacción con bloqueo del turno (S04).

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `numeroId` | entero | sí | Del resultado de #16. |
| `paseId` | entero | no | Pase a consumir si la especialidad lo requiere. Qué pasa si falta en una especialidad con pase: P-07. |

```json
{ "numeroId": 4501, "paseId": 77 }
```

**Respuesta 201** (`ConsultaDTO`, sección 1.9). Es el comprobante de RF-09: identificador, número, médico, fecha, hora y consultorio.

```json
{
  "id": 9001,
  "estado": "AGENDADA",
  "fecha": "2026-10-20",
  "numero": 2,
  "horaInicio": "09:20",
  "horaFin": "09:40",
  "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
  "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
  "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
  "paseId": 77,
  "agendadaEn": "2026-10-14T10:12:45-03:00",
  "canceladaEn": null,
  "motivoCancelacion": null
}
```

**Errores** (todos con mensaje que indica qué regla falló, RNF-23)

| Status | `code` | Cuándo |
|---|---|---|
| 404 | `NO_ENCONTRADO` | El número no existe. |
| 409 | `NUMERO_NO_DISPONIBLE` | Otro socio lo tomó antes. Mensaje: "El número seleccionado ya no está disponible. Elegí otro." El cliente vuelve a la disponibilidad (CU 3.2.2, 8.A). |
| 409 | `TURNO_SUSPENDIDO` | La fecha se suspendió mientras tanto (S04, concurrencia adicional). |
| 409 | `ANTICIPACION_MAXIMA` | La fecha está a más de 30 días. |
| 409 | `ANTICIPACION_MINIMA` | Faltan menos de 2 horas para el inicio del número. |
| 409 | `LIMITE_ESPECIALIDAD` | Ya tiene una consulta activa en esa especialidad. |
| 409 | `LIMITE_TOTAL` | Ya tiene 3 consultas activas. |
| 409 | `SUPERPOSICION_CONSULTA` | Se solapa en el tiempo con otra consulta agendada del socio. |
| 409 | `PASE_NO_VALIDO` | La especialidad requiere pase y no hay uno utilizable: no existe, es de otro socio o de otra especialidad, ya se usó (también si lo usó una reserva simultánea) o vence antes de la fecha de la consulta. |

Preguntas relacionadas: P-07, P-08.

<a id="e18"></a>
#### #18 · `GET /api/consultas`

- **Roles:** SOCIO (solo las propias).
- **RF:** RF-11. **Diseño:** `consultarHistorial(socioId, filtros: FiltroHistorialDTO): Page<ConsultaHistorialDTO>` (S05). **Estado:** PROPUESTA.

Incluye las canceladas. Los estados calculados `NO_ASISTIO` y `NO_ATENDIDA` se resuelven al consultar, con el aviso de llegada del día (S05).

| Parámetro | Tipo | Notas |
|---|---|---|
| `estado` | `EstadoConsulta` | Admite los siete valores, calculados incluidos. |
| `fechaDesde`, `fechaHasta` | fecha | |
| `especialidadId` | entero | |
| `medicoId` | entero | |
| `orden` | `fecha` o `especialidad` | Por defecto `fecha`. |
| `sentido` | `asc` o `desc` | Por defecto `desc` (la más reciente primero). |
| `page`, `size` | | Sección 1.3. |

**Respuesta 200** (`ConsultaHistorialDTO` = campos de `ConsultaDTO`, sección 1.9)

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
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
      "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
      "paseId": 77,
      "agendadaEn": "2026-10-14T10:12:45-03:00",
      "canceladaEn": null,
      "motivoCancelacion": null
    },
    {
      "id": 8120,
      "estado": "NO_ASISTIO",
      "fecha": "2026-09-30",
      "numero": 1,
      "horaInicio": "08:00",
      "horaFin": "08:20",
      "medico": { "id": 21, "nombre": "Jorge", "apellido": "Pereira" },
      "especialidad": { "id": 1, "nombre": "Medicina General", "requierePase": false },
      "consultorio": { "id": 6, "nombre": "Consultorio 6", "ubicacion": "Piso 2, ala sur" },
      "paseId": null,
      "agendadaEn": "2026-09-25T16:40:02-03:00",
      "canceladaEn": null,
      "motivoCancelacion": null
    }
  ],
  "page": 0,
  "size": 20,
  "total": 2
}
```

Preguntas relacionadas: P-09.

<a id="e19"></a>
#### #19 · `GET /api/consultas/{id}`

- **Roles:** SOCIO (solo las propias).
- **RF:** RF-11 ("con el detalle de cada una"). **Diseño:** S05. **Estado:** PROPUESTA.

Devuelve un `ConsultaHistorialDTO` (sección 1.9). Sin parámetros.

**Errores:** `404 NO_ENCONTRADO` si no existe **o es de otro socio** (P-10).

<a id="e20"></a>
#### #20 · `POST /api/consultas/{id}/cancelar`

- **Roles:** SOCIO (solo las propias). La cancelación a pedido del socio por un funcionario (RF-19) no está en este contrato.
- **RF:** RF-10. **Diseño:** `cancelarPorSocio(socioId, consultaId): CancelacionDTO` (S23). **Estado:** PROPUESTA.

Sin cuerpo. Pasa la consulta a `CANCELADA_SOCIO`, la conserva en el histórico, libera el número y devuelve el pase usado si sigue vigente, con su vencimiento original (RF-09, RF-10).

**Respuesta 200** (`CancelacionDTO`)

```json
{
  "consultaId": 9001,
  "estado": "CANCELADA_SOCIO",
  "canceladaEn": "2026-10-15T08:03:10-03:00",
  "paseDevuelto": true
}
```

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 404 | `NO_ENCONTRADO` | No existe o es de otro socio (P-10). |
| 409 | `CONSULTA_NO_AGENDADA` | La consulta ya no está en `AGENDADA`. |
| 409 | `CANCELACION_FUERA_DE_PLAZO` | Faltan menos de 2 horas para la hora del número. |
| 409 | `LLEGADA_YA_REGISTRADA` | El socio ya tiene aviso de llegada ese día (RF-10: "solo si no está presente"). |

<a id="e21"></a>
#### #21 · `GET /api/historia-clinica`

- **Roles:** SOCIO (solo la propia).
- **RF:** RF-12. **Diseño:** `obtenerHistoria(socioId, filtros: FiltroHistoriaDTO): HistoriaDTO` (S06). **Estado:** PROPUESTA.

El servidor autoriza la identidad del socio con el token. **No existe parámetro para consultar la historia de otra persona** (S06).

| Parámetro | Tipo | Notas |
|---|---|---|
| `fechaDesde`, `fechaHasta` | fecha | |
| `especialidadId` | entero | |
| `medicoId` | entero | |
| `texto` | texto | Búsqueda opcional en el tratamiento (RF-12). |
| `orden` | `fecha` o `especialidad` | Por defecto `fecha`. |
| `sentido` | `asc` o `desc` | Por defecto `desc`. |
| `page`, `size` | | Sección 1.3. Los filtros se combinan. |

**Respuesta 200** (`HistoriaDTO` con `AtencionDTO` en `items`; **PROPUESTA:** paginada, P-11). La lista no trae el contenido clínico: afección, tratamiento y observaciones solo viajan en #22.

```json
{
  "items": [
    {
      "id": 5530,
      "consultaId": 9001,
      "fecha": "2026-10-20",
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
      "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
      "cantidadPases": 1
    }
  ],
  "page": 0,
  "size": 20,
  "total": 1
}
```

<a id="e22"></a>
#### #22 · `GET /api/historia-clinica/{idAtencion}`

- **Roles:** SOCIO (solo la propia).
- **RF:** RF-12. **Diseño:** S06. **Estado:** PROPUESTA.

**Respuesta 200** (`AtencionDTO` con `PaseDTO`)

```json
{
  "id": 5530,
  "consultaId": 9001,
  "fecha": "2026-10-20",
  "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
  "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
  "afeccion": "Hipertensión arterial leve",
  "tratamiento": "Control de dieta y medicación indicada",
  "observaciones": null,
  "registradaEn": "2026-10-20T09:41:00-03:00",
  "pases": [
    {
      "id": 78,
      "especialidadDestino": { "id": 4, "nombre": "Nutrición", "requierePase": true },
      "emitidoEn": "2026-10-20T09:41:00-03:00",
      "venceEl": "2027-01-18",
      "situacion": "DISPONIBLE"
    }
  ]
}
```

`pases` son los emitidos en esa atención, con su vigencia (RF-12). `situacion` (**PROPUESTA** para el socio; RF-26 la define para el médico) se calcula de uso y vencimiento. `id` del pase es el que el socio envía como `paseId` en #17.

**Errores:** `404 NO_ENCONTRADO` si no existe o es de otra persona (P-10).

### 3.6 Funcionario: suspensión, rehabilitación, llegada y agendas

El cuerpo de suspender y rehabilitar usa `FiltroFechasDTO` y una lista de ids:

| Campo de `filtro` | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `medicoId` | entero | sí | |
| `especialidadId` | entero | sí | |
| `fechaDesde` | fecha | sí | |
| `fechaHasta` | fecha | sí | |

RF-14 y RF-15 identifican los turnos "por médico, especialidad y rango de fechas". El funcionario los lista con #15 y elige. `ids` son ids de turnos concretos (`TurnoDTO.id`) que deben caer dentro del `filtro`. Solo fechas actuales o futuras.

<a id="e23"></a>
#### #23 · `POST /api/turnos/suspensiones/previsualizar`

- **Roles:** FUNCIONARIO.
- **RF:** RF-14 (confirmación previa). **Diseño:** S08 ("antes de confirmar, se muestran las fechas y la cantidad de consultas Agendadas que se cancelarán"). **Estado:** PROPUESTA.

Es de solo lectura: no cambia nada. Se usa `POST` porque lleva una lista de ids.

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `filtro` | `FiltroFechasDTO` | sí | |
| `ids` | lista de enteros | sí | Al menos uno. Qué significa "todos los del rango": P-12. |

```json
{
  "filtro": { "medicoId": 17, "especialidadId": 3, "fechaDesde": "2026-10-20", "fechaHasta": "2026-11-03" },
  "ids": [301, 308, 315]
}
```

**Respuesta 200**

```json
{
  "fechasAfectadas": [
    { "turnoId": 301, "fecha": "2026-10-20", "horaInicio": "09:00", "horaFin": "10:30", "consultasACancelar": 2 },
    { "turnoId": 308, "fecha": "2026-10-27", "horaInicio": "09:00", "horaFin": "10:30", "consultasACancelar": 3 },
    { "turnoId": 315, "fecha": "2026-11-03", "horaInicio": "09:00", "horaFin": "10:30", "consultasACancelar": 0 }
  ],
  "cantidadConsultasACancelar": 5
}
```

`cantidadConsultasACancelar` es el total de consultas en `AGENDADA` de esos turnos.

**Errores:** `404 NO_ENCONTRADO` (algún id no existe), `409 TURNO_NO_SUSPENDIBLE` (algún turno no está activo o su fecha ya pasó).

<a id="e24"></a>
#### #24 · `POST /api/turnos/suspensiones`

- **Roles:** FUNCIONARIO.
- **RF:** RF-14. **Diseño:** `suspenderFechas(filtro, ids): ResultadoFechasDTO` (S08). **Estado:** PROPUESTA.

Suspende de inmediato, cancela por la institución las consultas `AGENDADA`, devuelve los pases y registra los avisos a los socios con la observación, todo en una transacción y todo o nada (S08, diseño 5.2). No borra nada ni toca el patrón semanal.

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `filtro` | `FiltroFechasDTO` | sí | |
| `ids` | lista de enteros | sí | Al menos uno. |
| `observacion` | texto | no | Se incluye en la notificación a cada socio. |
| `cantidadConsultasConfirmada` | entero ≥ 0 | sí | **PROPUESTA:** el `cantidadConsultasACancelar` que el funcionario vio en #23. Implementa S08: "si esta cambió, se solicita una nueva confirmación antes de aplicar cambios". |

```json
{
  "filtro": { "medicoId": 17, "especialidadId": 3, "fechaDesde": "2026-10-20", "fechaHasta": "2026-11-03" },
  "ids": [301, 308, 315],
  "observacion": "Se creará otro turno la semana próxima.",
  "cantidadConsultasConfirmada": 5
}
```

**Respuesta 200** (`ResultadoFechasDTO`)

```json
{
  "turnos": [
    { "turnoId": 301, "fecha": "2026-10-20" },
    { "turnoId": 308, "fecha": "2026-10-27" },
    { "turnoId": 315, "fecha": "2026-11-03" }
  ],
  "consultasCanceladas": 5
}
```

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 404 | `NO_ENCONTRADO` | Algún id no existe. |
| 409 | `TURNO_NO_SUSPENDIBLE` | Algún turno ya no está activo o su fecha pasó. No se suspende ninguno. |
| 409 | `CONFIRMACION_DESACTUALIZADA` | La cantidad de consultas afectadas cambió desde la previsualización. No se aplica nada; el cliente vuelve a llamar #23 y pide una nueva confirmación. |

<a id="e25"></a>
#### #25 · `POST /api/turnos/rehabilitaciones`

- **Roles:** FUNCIONARIO.
- **RF:** RF-15. **Diseño:** `rehabilitarFechas(filtro, ids): ResultadoFechasDTO` (S09). **Estado:** PROPUESTA.

Reactiva turnos suspendidos sin modificar médico, especialidad, fecha, consultorio ni números. **No restaura** las consultas canceladas (RF-15).

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `filtro` | `FiltroFechasDTO` | sí | |
| `ids` | lista de enteros | sí | Al menos uno; turnos suspendidos de fechas actuales o futuras. |

```json
{
  "filtro": { "medicoId": 17, "especialidadId": 3, "fechaDesde": "2026-10-20", "fechaHasta": "2026-11-03" },
  "ids": [301, 308]
}
```

**Respuesta 200** (`ResultadoFechasDTO`; `consultasCanceladas` es siempre 0 acá)

```json
{
  "turnos": [
    { "turnoId": 301, "fecha": "2026-10-20" },
    { "turnoId": 308, "fecha": "2026-10-27" }
  ],
  "consultasCanceladas": 0
}
```

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 404 | `NO_ENCONTRADO` | Algún id no existe. |
| 409 | `TURNO_NO_REHABILITABLE` | Algún turno no está suspendido o su fecha pasó. |
| 409 | `MEDICO_INACTIVO` | El médico no está activo. |
| 409 | `SOLAPAMIENTO_TURNO` | Los números se solapan con otro turno activo del mismo médico o consultorio. No se modifica ninguna fecha ni se cancela ninguna consulta ajena (S09). |

<a id="e26"></a>
#### #26 · `GET /api/avisos-llegada/consultas-hoy`

- **Roles:** FUNCIONARIO.
- **RF:** RF-16. **Diseño:** `obtenerConsultasHoy(ci): List<ConsultaDTO>` (S10). **Estado:** PROPUESTA.

Devuelve las consultas **en `AGENDADA` de hoy** del socio con esa CI (mismo criterio que `buscarAgendadasHoy(ci)`).

| Parámetro | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `ci` | texto | sí | CI del socio, sección 1.6. |

**Respuesta 200** (`ConsultaDTO`, sección 1.9, todas con `fecha` de hoy y `estado: "AGENDADA"`)

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
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
      "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
      "paseId": 77,
      "agendadaEn": "2026-10-14T10:12:45-03:00",
      "canceladaEn": null,
      "motivoCancelacion": null
    }
  ]
}
```

Sin consultas hoy: `200` con `{ "items": [] }`; el cliente muestra "El socio no posee consultas agendadas para el día de hoy" (CU 3.3.4, 3.A.2).

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | Falta `ci` o no tiene forma válida. |
| 403 | `CONFLICTO_DE_INTERES` | La CI es la del propio funcionario (3.1.5, CU 3.3.4 3.B). Mensaje: "No podés registrar tu propia llegada. Pedile a otro funcionario que lo haga." |

Preguntas relacionadas: P-15.

<a id="e27"></a>
#### #27 · `POST /api/avisos-llegada`

- **Roles:** FUNCIONARIO.
- **RF:** RF-16. **Diseño:** `registrarAviso(ci, funcionarioId, fecha): AvisoLlegadaDTO` (S10). **Estado:** PROPUESTA.

El `funcionarioId` sale del token y la `fecha` es la de hoy según el servidor: **el cliente no las envía** (no hay ventana de antelación ni se puede registrar otro día).

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `ci` | texto | sí | |

```json
{ "ci": "45678911" }
```

**Respuesta 201** si crea el aviso, **200** si el aviso de hoy ya existía y se devuelve el original sin tocarlo (conserva la primera hora y el primer funcionario, diseño 3.3.4). Mismo cuerpo (`AvisoLlegadaDTO`):

```json
{
  "id": 7001,
  "socio": { "ci": "45678911", "nombre": "Lucía", "apellido": "Fernández" },
  "fecha": "2026-10-20",
  "registradaEn": "2026-10-20T08:55:12-03:00",
  "registradaPor": { "id": 31, "nombre": "Pablo", "apellido": "Gómez" }
}
```

El cliente distingue "registrado ahora" de "ya estaba registrado" por el status (201 o 200).

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | CI vacía o con forma inválida. |
| 403 | `CONFLICTO_DE_INTERES` | La CI es la del propio funcionario. |
| 409 | `SIN_CONSULTAS_HOY` | El socio no tiene ninguna consulta `AGENDADA` hoy (también si la CI no es de ningún socio). No se crea aviso. |

<a id="e28"></a>
#### #28 · `GET /api/agendas`

- **Roles:** FUNCIONARIO.
- **RF:** RF-18. **Diseño:** `consultarAgendas(filtros: FiltroAgendaDTO): Page<AgendaOperativaDTO>` (S12). **Estado:** PROPUESTA.

Detalle operativo, **sin datos clínicos**. Filtrando por hoy y por llegada se obtiene la lista de socios presentes; el cliente repite el pedido cada 15 segundos mientras la pantalla está visible (arquitectura 8.5).

| Parámetro | Tipo | Notas |
|---|---|---|
| `ci` | texto | CI del socio. |
| `consultaId` | entero | Identificador de la consulta. |
| `fecha` | fecha | **Una sola fecha**, no un rango: el Diseño aclara que no se inventa un rango para RF-18 (S12). |
| `medicoId` | entero | |
| `estado` | `EstadoConsulta` | |
| `llegada` | booleano | `true` solo con aviso de llegada, `false` solo sin él. |
| `orden` | `fechaHora` o `horaLlegada` | Por defecto `fechaHora`. |
| `sentido` | `asc` o `desc` | Por defecto `asc`. |
| `page`, `size` | | Sección 1.3. |

**Respuesta 200** (`AgendaOperativaDTO`)

```json
{
  "items": [
    {
      "consultaId": 9001,
      "socio": { "ci": "45678911", "nombre": "Lucía", "apellido": "Fernández" },
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
      "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
      "fecha": "2026-10-20",
      "horaInicio": "09:20",
      "horaFin": "09:40",
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
      "estado": "AGENDADA",
      "llegadaEn": "2026-10-20T08:55:12-03:00"
    }
  ],
  "page": 0,
  "size": 20,
  "total": 1
}
```

`llegadaEn` es `null` si el socio no registró llegada ese día.

### 3.7 Médico

<a id="e29"></a>
#### #29 · `GET /api/medico/turnos`

- **Roles:** MEDICO (solo los propios).
- **RF:** RF-21. **Diseño:** `consultarTurnosDelMedico(medicoId, fecha): TurnosPacientesDTO` (S13). **Estado:** PROPUESTA.

El Diseño devuelve turnos y pacientes en un solo DTO. **PROPUESTA:** se parte en dos pedidos para seguir el flujo del CU 3.4.1 (elegir fecha, ver sus turnos, elegir un turno, ver sus números): este endpoint trae los turnos del día y #30 el detalle de un turno.

| Parámetro | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `fecha` | fecha | sí | |

**Respuesta 200**

```json
{
  "items": [
    {
      "id": 301,
      "fecha": "2026-10-20",
      "horaInicio": "09:00",
      "horaFin": "10:30",
      "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
      "estado": "ACTIVO",
      "cantidadNumeros": 3,
      "cantidadReservados": 2
    }
  ]
}
```

Sin turnos ese día: `{ "items": [] }`.

<a id="e30"></a>
#### #30 · `GET /api/medico/turnos/{id}/numeros`

- **Roles:** MEDICO (solo turnos propios).
- **RF:** RF-21. **Diseño:** S13. **Estado:** PROPUESTA.

Todos los números del turno, con el paciente y el aviso de llegada de los reservados. El número no impone una cola: el médico decide a quién llamar (RF-21).

| Parámetro | Tipo | Notas |
|---|---|---|
| `llegada` | booleano | Filtro por aviso de llegada. |
| `orden` | `hora` o `horaLlegada` | Por defecto `hora` (hora del número). |
| `sentido` | `asc` o `desc` | Por defecto `asc`. |

**Respuesta 200**

```json
{
  "turno": {
    "id": 301,
    "fecha": "2026-10-20",
    "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
    "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
    "estado": "ACTIVO"
  },
  "items": [
    {
      "numeroId": 4500,
      "numero": 1,
      "horaInicio": "09:00",
      "horaFin": "09:20",
      "consulta": {
        "id": 9000,
        "estado": "AGENDADA",
        "paciente": { "ci": "34567894", "nombre": "Carlos", "apellido": "Silva" },
        "llegadaEn": "2026-10-20T08:40:30-03:00"
      },
      "disponible": false
    },
    {
      "numeroId": 4501,
      "numero": 2,
      "horaInicio": "09:20",
      "horaFin": "09:40",
      "consulta": null,
      "disponible": true
    }
  ]
}
```

Un número sin consulta (o con la consulta cancelada) trae `consulta: null` y se muestra "Sin reserva"; `disponible` es `true` solo si todavía puede agendarse (anticipación). Un número reservado trae `disponible: false`. `consulta.llegadaEn` es `null` si no hubo aviso de llegada. `consulta.id` es el que se usa en #31.

**Errores:** `404 NO_ENCONTRADO` si el turno no existe o no es del médico (P-10).

<a id="e31"></a>
#### #31 · `POST /api/medico/consultas/{id}/resultado`

- **Roles:** MEDICO (solo consultas propias).
- **RF:** RF-23, RF-24. **Diseño:** `registrarResultado(medicoId, consultaId, datos: ResultadoConsultaDTO): ResultadoConsultaDTO` y `validarYCrearEnAtencion(atencionId, solicitudes: List<PaseNuevoDTO>): List<PaseDTO>` (S14, S15). **Estado:** PROPUESTA.

Una sola llamada, una sola transacción: la atención y sus pases se guardan juntos o no se guarda nada. Los pases no se pueden emitir después ni desde una atención ya guardada (RF-24). No hay borradores. El resultado es **definitivo** (sin rectificación ni reapertura). Ambas ramas exigen que el socio tenga aviso de llegada de hoy y que la consulta sea de hoy, esté `AGENDADA` y sea del médico.

**Cuerpo** (`ResultadoConsultaDTO`, entrada)

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `resultado` | `ATENDIDA` o `NO_SE_PRESENTO` | sí | |
| `afeccion` | texto | si `ATENDIDA` | Obligatoria. Con `NO_SE_PRESENTO` debe omitirse. |
| `tratamiento` | texto | no | Solo con `ATENDIDA`. |
| `observaciones` | texto | no | Solo con `ATENDIDA`. |
| `pases` | lista de `PaseNuevoDTO` | no | Solo con `ATENDIDA`. |
| `pases[].especialidadDestinoId` | entero | sí | Puede ser la propia especialidad. No se puede repetir en la lista. |
| `pases[].vigenciaDias` | entero 1 a 365 | no | **PROPUESTA:** si se omite, 90 (vigencia inicial, 3.1.3). RF-24: "hasta qué fecha vale". |

```json
{
  "resultado": "ATENDIDA",
  "afeccion": "Hipertensión arterial leve",
  "tratamiento": "Control de dieta y medicación indicada",
  "observaciones": null,
  "pases": [
    { "especialidadDestinoId": 4, "vigenciaDias": 90 }
  ]
}
```

```json
{ "resultado": "NO_SE_PRESENTO" }
```

**Respuesta 200** (`ResultadoConsultaDTO`, salida)

```json
{
  "consultaId": 9001,
  "estado": "ATENDIDA",
  "atencionId": 5530,
  "registradoEn": "2026-10-20T09:41:00-03:00",
  "pases": [
    {
      "id": 78,
      "especialidadDestino": { "id": 4, "nombre": "Nutrición", "requierePase": true },
      "emitidoEn": "2026-10-20T09:41:00-03:00",
      "venceEl": "2027-01-18"
    }
  ]
}
```

Con `NO_SE_PRESENTO`: `estado` es `NO_SE_PRESENTO`, `atencionId` es `null` y `pases` es `[]`. Ese estado no libera el número ni devuelve el pase usado, y el aviso de llegada sigue valiendo para las demás consultas del día (RF-23). Las notificaciones al socio son internas (no cambian la respuesta); no incluyen datos clínicos.

**Errores**

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | Falta `afeccion` con `ATENDIDA`; llegan campos clínicos o pases con `NO_SE_PRESENTO`; `vigenciaDias` fuera de 1 a 365; la misma especialidad destino repetida. |
| 403 | `CONFLICTO_DE_INTERES` | El médico es el propio socio de esa consulta (3.1.5). |
| 404 | `NO_ENCONTRADO` | La consulta no existe o no es del médico (P-10). |
| 409 | `CONSULTA_NO_AGENDADA` | La consulta ya no está en `AGENDADA` (ya tiene resultado, o se canceló). |
| 409 | `CONSULTA_NO_ES_DE_HOY` | La consulta no corresponde al día de hoy. |
| 409 | `SIN_AVISO_LLEGADA` | El socio no registró llegada hoy. En ambas ramas (S14). |
| 409 | `PASE_DUPLICADO` | El socio ya tiene un pase disponible y vigente para esa especialidad destino, o ya tiene una consulta `AGENDADA` pendiente en ella. La atención que se está guardando no cuenta como pendiente (RF-24). No se guarda nada. |

### 3.8 Notificaciones y dispositivos

<a id="e32"></a>
#### #32 · `GET /api/notificaciones`

- **Roles:** SOCIO (solo las propias).
- **RF:** RNF-24 ("por la interfaz del sistema"), RNF-26. **Diseño:** sin operación de lectura en 2.3 (solo `registrarAvisoPendiente`); el modelo de datos tiene la tabla Notificacion. **Estado:** PROPUESTA.

| Parámetro | Tipo | Notas |
|---|---|---|
| `page`, `size` | | Sección 1.3. |

Orden **PROPUESTA:** más reciente primero (`creadaEn` descendente), sin parámetros de orden.

**Respuesta 200**

```json
{
  "items": [
    {
      "id": 15001,
      "tipo": "SUSPENSION",
      "consultaId": 9001,
      "contenido": "Se suspendió el turno del 20/10/2026 con la Dra. Rodríguez. Se creará otro turno la semana próxima.",
      "creadaEn": "2026-10-16T11:20:00-03:00"
    }
  ],
  "page": 0,
  "size": 20,
  "total": 1
}
```

El `contenido` de `HISTORIA_ACTUALIZADA` nunca incluye afección, tratamiento ni observaciones (arquitectura 8.2). Preguntas relacionadas: P-14.

<a id="e33"></a>
#### #33 · `POST /api/dispositivos`

- **Roles:** SOCIO.
- **RF:** RNF-24 (push en Android si el socio instaló la app y otorgó permiso). **Diseño:** sin operación en 2.3; el modelo de datos tiene la tabla DispositivoPush. **Estado:** PROPUESTA.

Registra el token de Firebase del dispositivo del socio autenticado.

**Cuerpo**

| Campo | Tipo | Obligatorio | Notas |
|---|---|---|---|
| `token` | texto | sí | Token del servicio push. |

```json
{ "token": "fcm-token-de-ejemplo" }
```

**Respuesta 201** si lo registra, **200** si ese token ya estaba registrado para este socio (idempotente).

```json
{ "id": 61, "habilitado": true, "registradoEn": "2026-10-14T10:20:00-03:00" }
```

Preguntas relacionadas: P-14.

### 3.9 Estadísticas (administrador)

Las tres usan el mismo `FiltroEstadisticaDTO`, que viaja en la query:

| Parámetro | Tipo | Notas |
|---|---|---|
| `fechaDesde` | fecha | Opcional. Por defecto, el primer día del mes en curso (RF-44, CU 3.5.5). |
| `fechaHasta` | fecha | Opcional. Por defecto, el último día del mes en curso. |

Cada respuesta repite `desde` y `hasta`, el período realmente aplicado. Un denominador cero se informa como **"Sin datos"** y un numerador cero con denominador positivo como **0 %** (RF-44): en el JSON, un porcentaje o tasa en `null` significa "Sin datos"; el `0` es 0 %. Los porcentajes van como número entre 0 y 100, con hasta 2 decimales (**PROPUESTA**, P-13). Estas consultas pueden demorar más que las demás (RNF-17): el cliente muestra que la operación está en curso.

Errores comunes: `400 VALIDACION` (fecha mal formada o rango invertido).

<a id="e34"></a>
#### #34 · `GET /api/estadisticas/especialidades`

- **Roles:** ADMINISTRADOR.
- **RF:** RF-39. **Diseño:** `calcularPorEspecialidad(filtro): List<EstadisticaEspecialidadDTO>` (S20). **Estado:** PROPUESTA.

Consultas agendadas en el período, **contadas por la fecha en que se agendaron** (`agendadaEn`), incluidas las que luego se cancelaron.

**Respuesta 200**

```json
{
  "desde": "2026-10-01",
  "hasta": "2026-10-31",
  "items": [
    { "especialidad": { "id": 1, "nombre": "Medicina General", "requierePase": false }, "cantidadConsultas": 128 },
    { "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true }, "cantidadConsultas": 42 }
  ]
}
```

<a id="e35"></a>
#### #35 · `GET /api/estadisticas/turnos`

- **Roles:** ADMINISTRADOR.
- **RF:** RF-40. **Diseño:** `calcularPorTurno(filtro): List<EstadisticaTurnoDTO>` (S21). **Estado:** PROPUESTA.

Porcentaje de números ocupados sobre los ofrecidos, en las fechas del período en que la fecha del turno estuvo activa. Ocupado: consulta `AGENDADA`, `ATENDIDA`, `NO_ASISTIO`, `NO_ATENDIDA` o `NO_SE_PRESENTO`; las canceladas lo dejan libre. Qué es "cada turno" (el patrón semanal o la fecha concreta): P-13. **PROPUESTA:** una fila por patrón semanal.

**Respuesta 200**

```json
{
  "desde": "2026-10-01",
  "hasta": "2026-10-31",
  "items": [
    {
      "turnoSemanalId": 120,
      "medico": { "id": 17, "nombre": "Marta", "apellido": "Rodríguez" },
      "especialidad": { "id": 3, "nombre": "Cardiología", "requierePase": true },
      "consultorio": { "id": 5, "nombre": "Consultorio 5", "ubicacion": "Piso 2, ala norte" },
      "diaSemana": 2,
      "numerosOfrecidos": 12,
      "numerosOcupados": 9,
      "porcentajeUtilizacion": 75.0
    },
    {
      "turnoSemanalId": 121,
      "medico": { "id": 21, "nombre": "Jorge", "apellido": "Pereira" },
      "especialidad": { "id": 1, "nombre": "Medicina General", "requierePase": false },
      "consultorio": { "id": 6, "nombre": "Consultorio 6", "ubicacion": "Piso 2, ala sur" },
      "diaSemana": 4,
      "numerosOfrecidos": 0,
      "numerosOcupados": 0,
      "porcentajeUtilizacion": null
    }
  ]
}
```

La segunda fila muestra "Sin datos" (no hubo números ofrecidos en fechas activas del período).

<a id="e36"></a>
#### #36 · `GET /api/estadisticas/consultas`

- **Roles:** ADMINISTRADOR.
- **RF:** RF-41. **Diseño:** `calcularConsultas(filtro): EstadisticaConsultaDTO` (S22). **Estado:** PROPUESTA.

Consultas del período por estado, según la **fecha de la consulta**, con los siete estados (los calculados incluidos), y la tasa de cancelación por el socio: canceladas por el socio sobre el total.

**Respuesta 200**

```json
{
  "desde": "2026-10-01",
  "hasta": "2026-10-31",
  "total": 200,
  "porEstado": {
    "AGENDADA": 40,
    "ATENDIDA": 110,
    "CANCELADA_SOCIO": 20,
    "CANCELADA_INSTITUCION": 8,
    "NO_ASISTIO": 14,
    "NO_ATENDIDA": 5,
    "NO_SE_PRESENTO": 3
  },
  "tasaCancelacionSocio": 10.0
}
```

`total` cero: `tasaCancelacionSocio` es `null` ("Sin datos"). Con consultas y ninguna cancelada por el socio: `0`.

---

## 4. Matriz de roles por endpoint

✔ = permitido. "Auth" = cualquier rol autenticado. Todo lo que no tiene ✔ responde `403 SIN_PERMISO` (o `401` si no hay sesión válida).

| # | Endpoint | Público | SOCIO | FUNCIONARIO | MEDICO | ADMINISTRADOR |
|---|---|:-:|:-:|:-:|:-:|:-:|
| 1 | `POST /api/auth/login` | ✔ | | | | |
| 2 | `POST /api/auth/refresh` | ✔ (cookie) | | | | |
| 3 | `POST /api/auth/logout` | | ✔ | ✔ | ✔ | ✔ |
| 4 | `POST /api/auth/primer-ingreso/solicitar` | ✔ | | | | |
| 5 | `POST /api/auth/primer-ingreso/completar` | ✔ (token) | | | | |
| 6 | `GET /api/especialidades` | | ✔ | ✔ | ✔ | ✔ |
| 7 | `POST /api/especialidades` | | | | | ✔ |
| 8 | `GET /api/consultorios` | | ✔ | ✔ | ✔ | ✔ |
| 9 | `POST /api/consultorios` | | | | | ✔ |
| 10 | `GET /api/medicos` | | ✔ | ✔ | ✔ | ✔ |
| 11 | `POST /api/usuarios` | | | | | ✔ |
| 12 | `GET /api/usuarios` | | | | | ✔ |
| 13 | `POST /api/turnos-semanales` | | | ✔ | | |
| 14 | `GET /api/turnos-semanales/{id}` | | | ✔ | | |
| 15 | `GET /api/turnos` | | | ✔ | | |
| 16 | `GET /api/disponibilidad` | | ✔ | | | |
| 17 | `POST /api/consultas` | | ✔ | | | |
| 18 | `GET /api/consultas` | | ✔ | | | |
| 19 | `GET /api/consultas/{id}` | | ✔ | | | |
| 20 | `POST /api/consultas/{id}/cancelar` | | ✔ | | | |
| 21 | `GET /api/historia-clinica` | | ✔ | | | |
| 22 | `GET /api/historia-clinica/{idAtencion}` | | ✔ | | | |
| 23 | `POST /api/turnos/suspensiones/previsualizar` | | | ✔ | | |
| 24 | `POST /api/turnos/suspensiones` | | | ✔ | | |
| 25 | `POST /api/turnos/rehabilitaciones` | | | ✔ | | |
| 26 | `GET /api/avisos-llegada/consultas-hoy` | | | ✔ | | |
| 27 | `POST /api/avisos-llegada` | | | ✔ | | |
| 28 | `GET /api/agendas` | | | ✔ | | |
| 29 | `GET /api/medico/turnos` | | | | ✔ | |
| 30 | `GET /api/medico/turnos/{id}/numeros` | | | | ✔ | |
| 31 | `POST /api/medico/consultas/{id}/resultado` | | | | ✔ | |
| 32 | `GET /api/notificaciones` | | ✔ | | | |
| 33 | `POST /api/dispositivos` | | ✔ | | | |
| 34 | `GET /api/estadisticas/especialidades` | | | | | ✔ |
| 35 | `GET /api/estadisticas/turnos` | | | | | ✔ |
| 36 | `GET /api/estadisticas/consultas` | | | | | ✔ |

Además del rol, el servidor aplica la **propiedad del recurso**: el socio solo ve lo propio (#17 a #22, #32, #33) y el médico solo lo propio (#29 a #31). Y el **conflicto de interés** de 3.1.5 (#26, #27, #31).

## 5. Error uniforme y catálogo de códigos

### 5.1 Forma del error

Toda respuesta de error (4xx y 5xx) tiene este cuerpo y ningún otro campo:

```json
{
  "code": "NUMERO_NO_DISPONIBLE",
  "message": "El número seleccionado ya no está disponible. Elegí otro."
}
```

- `code`: texto estable en `MAYÚSCULAS_CON_GUION_BAJO`. Es lo que el cliente usa para decidir qué hacer. No cambia aunque cambie el texto.
- `message`: texto en español, sin términos técnicos, que dice qué pasó y qué puede hacer el usuario (RNF-23). Es seguro para mostrarlo tal cual.
- Nunca se incluyen trazas, SQL, nombres de tablas, datos clínicos ni nada que confirme la existencia de una cuenta (RNF-10, RNF-12, diseño 4.5).

Una respuesta de error sin cuerpo JSON válido (por ejemplo un corte del proxy) la trata el cliente como `500 ERROR_INTERNO`.

Qué hace el cliente por status: `401` fuera del login → intenta `refresh` una vez y, si falla, vuelve al login; `403`, `404`, `409` → muestra `message`; `400` → muestra `message` (P-01); `500` → mensaje genérico.

### 5.2 Códigos generales

| Status | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDACION` | Pedido mal formado o dato inválido (falta un campo, formato, rango, orden desconocido). El `message` dice cuál. |
| 401 | `NO_AUTENTICADO` | Falta el token, está vencido o es inválido, la sesión fue revocada o la cuenta fue inactivada (RNF-05, RNF-08). |
| 403 | `SIN_PERMISO` | El rol no puede usar este endpoint. |
| 404 | `NO_ENCONTRADO` | El recurso no existe, o existe pero es de otra persona (P-10). |
| 500 | `ERROR_INTERNO` | Falla inesperada. Mensaje fijo: "Ocurrió un problema de nuestro lado. Intentá de nuevo en unos minutos." |

### 5.3 Códigos de sesión y primer ingreso

| Status | `code` | Endpoint | Cuándo |
|---|---|---|---|
| 401 | `CREDENCIALES_INVALIDAS` | #1 | Cualquier rechazo del login, sin distinguir motivo. |
| 401 | `SESION_INVALIDA` | #2 | Cookie de renovación ausente, vencida o revocada. |
| 403 | `CSRF_INVALIDO` | #2, #3 | Falla la protección CSRF (P-02). |
| 400 | `ENLACE_INVALIDO` | #5 | Enlace inexistente, vencido, usado o cuenta inactivada. |

### 5.4 Códigos de administración

| Status | `code` | Endpoint | Cuándo |
|---|---|---|---|
| 409 | `ESPECIALIDAD_DUPLICADA` | #7 | Nombre repetido (normalizado). |
| 409 | `CONSULTORIO_DUPLICADO` | #9 | Nombre o número repetido (normalizado). |
| 400 | `CI_INVALIDA` | #11 | Dígito verificador incorrecto. |
| 409 | `DATOS_PERSONA_DISCORDANTES` | #11 | CI existente con nombre, apellido o fecha de nacimiento distintos. |
| 409 | `SOCIO_DUPLICADO` | #11 | La CI ya tiene cuenta de socio. |
| 409 | `EMPLEADO_DUPLICADO` | #11 | La CI ya tiene cuenta de empleado habilitada o pendiente. |

### 5.5 Códigos de turnos

| Status | `code` | Endpoint | Cuándo |
|---|---|---|---|
| 400 | `ESPECIALIDAD_NO_DEL_MEDICO` | #13 | La especialidad no es de ese médico. |
| 409 | `MEDICO_INACTIVO` | #13, #25 | El médico no está activo. |
| 409 | `SOLAPAMIENTO_TURNO` | #13, #25 | Cruce de horarios con otro turno activo del médico o del consultorio. |
| 409 | `TURNO_NO_SUSPENDIBLE` | #23, #24 | Turno no activo o de fecha pasada. |
| 409 | `TURNO_NO_REHABILITABLE` | #25 | Turno no suspendido o de fecha pasada. |
| 409 | `CONFIRMACION_DESACTUALIZADA` | #24 | La cantidad de consultas afectadas cambió desde la previsualización. |

### 5.6 Códigos de agenda y consultas

| Status | `code` | Endpoint | Cuándo |
|---|---|---|---|
| 409 | `NUMERO_NO_DISPONIBLE` | #17 | El número ya fue tomado. |
| 409 | `TURNO_SUSPENDIDO` | #17 | La fecha del turno está suspendida. |
| 409 | `ANTICIPACION_MAXIMA` | #17 | A más de 30 días. |
| 409 | `ANTICIPACION_MINIMA` | #17 | A menos de 2 horas del inicio del número. |
| 409 | `LIMITE_ESPECIALIDAD` | #17 | Ya hay una consulta activa en esa especialidad. |
| 409 | `LIMITE_TOTAL` | #17 | Ya hay 3 consultas activas. |
| 409 | `SUPERPOSICION_CONSULTA` | #17 | Se solapa con otra consulta del socio. |
| 409 | `PASE_NO_VALIDO` | #17 | No hay pase utilizable para la especialidad y la fecha. |
| 409 | `CONSULTA_NO_AGENDADA` | #20, #31 | La consulta no está en `AGENDADA`. |
| 409 | `CANCELACION_FUERA_DE_PLAZO` | #20 | A menos de 2 horas de la hora del número. |
| 409 | `LLEGADA_YA_REGISTRADA` | #20 | El socio ya registró llegada ese día. |

### 5.7 Códigos de llegada y atención

| Status | `code` | Endpoint | Cuándo |
|---|---|---|---|
| 403 | `CONFLICTO_DE_INTERES` | #26, #27, #31 | El empleado opera sobre su propia cuenta de socio (3.1.5). |
| 409 | `SIN_CONSULTAS_HOY` | #27 | El socio no tiene consultas `AGENDADA` hoy. |
| 409 | `SIN_AVISO_LLEGADA` | #31 | El socio no registró llegada hoy. |
| 409 | `CONSULTA_NO_ES_DE_HOY` | #31 | La consulta no es de hoy. |
| 409 | `PASE_DUPLICADO` | #31 | Pase disponible vigente o consulta agendada pendiente en esa especialidad. |

## 6. Pantallas de los mockups y endpoints que las alimentan

Los títulos y los RF son los de `diseno.md` sección 6. Las imágenes no se pudieron ver (sección 0), así que la relación sale del título y de los RF que cada pantalla dice cubrir. Las pantallas de empleados son web; las del socio son móviles, y el socio también las tiene en web (RNF-01, RNF-02).

| Pantalla (Diseño) | RF | Endpoints |
|---|---|---|
| 6.1.1 Iniciar sesión (web, empleados) | 01, 02 | #1 (con `acceso: "EMPLEADO"`), #4 y #5 (primer ingreso), #2 y #3 (sesión) |
| 6.1.2 Registrar aviso de llegada | 16 | #26 (buscar socio por CI y listar sus consultas de hoy), #27 (marcar llegada) |
| 6.1.3 Alta de turno semanal | 13 | #10 (médicos con sus especialidades), #8 (consultorios), #6 (nombres de especialidad), #13 (guardar) |
| 6.1.4 Consultar turnos, suspender y rehabilitar fechas | 14, 15, 17 | #15 (lista y selección), #14 (configuración semanal), #10 y #6 (filtros), #23 (confirmación previa), #24 (suspender), #25 (rehabilitar) |
| 6.1.5 Consultar agendas | 18 | #28 (con refresco cada 15 s), #10 (filtro de médico) |
| 6.1.6 Consultar turnos y pacientes de una fecha | 21 | #29 (turnos del día), #30 (números y pacientes, con refresco cada 15 s) |
| 6.1.7 Registrar atención y emitir pases | 23, 24 | #31 (guardar), #6 (especialidades de destino de los pases) |
| 6.1.8 Registrar y consultar usuarios | 31, 35 | #11 (alta), #12 (consulta), #6 (especialidades del médico) |
| 6.1.9 Registrar especialidades y consultorios | 29, 33 | #7 y #9 (altas), #6 y #8 (listas) |
| 6.1.10 Consultar estadísticas | 39, 40, 41 | #34, #35, #36 |
| 6.2.1 Iniciar sesión y primer ingreso (móvil, socio) | 01, 02 | #1 (con `acceso: "SOCIO"`), #4, #5, #2, #3, #33 (registrar el dispositivo tras iniciar sesión, si el socio dio permiso) |
| 6.2.2 Consultar disponibilidad | 08 | #16, #6 (especialidad obligatoria), #10 (médico) |
| 6.2.3 Agendar consulta | 09 | #17 (confirmar). Los datos a confirmar vienen del resultado de #16; el pase, de #22 (P-07, P-08) |
| 6.2.4 Consultar histórico de agendas | 11 | #18 (lista), #19 (detalle), #20 (cancelar, RF-10), #6 y #10 (filtros) |
| 6.2.5 Consultar historia clínica | 12 | #21 (lista), #22 (detalle), #6 y #10 (filtros) |
| Sin mockup: lista de notificaciones del socio | RNF-24 | #32 |

## 7. Correcciones y contradicciones resueltas

### 7.1 Correcciones a las rutas de partida

Las rutas de partida se mantuvieron todas tal cual. Cambios en el contenido:

1. **`POST /api/consultas`:** el cuerpo usa `numeroId` y `paseId?` (no `idNumero` e `idPase?`), que son los nombres de la firma `agendar(socioId, numeroId, paseId?)` del Diseño 2.3. Se aplicó la misma regla a todo el contrato: referencias como `<entidad>Id`.
2. **Login y refresh:** la respuesta mantiene `role` como se pidió; es la única excepción a `rol` (P-22). El refresh devuelve la misma forma que el login.
3. **`primer-ingreso/solicitar`:** "siempre 202" vale para todo pedido bien formado. Un pedido mal formado (falta un campo) recibe `400 VALIDACION` porque no depende de la CI ni de su existencia.
4. **Suspensiones:** el Diseño exige volver a pedir confirmación si la cantidad de consultas cambió entre la previsualización y la confirmación (S08). Por eso #24 lleva `cantidadConsultasConfirmada` y puede responder `409 CONFIRMACION_DESACTUALIZADA`.
5. **Médico:** el Diseño define una sola operación `consultarTurnosDelMedico(medicoId, fecha): TurnosPacientesDTO`. Se mantienen los dos endpoints pedidos, #29 y #30, como una división de ese DTO (la justificación está en #29).
6. **Consultas de hoy:** `GET /api/avisos-llegada/consultas-hoy?ci=` devuelve solo `AGENDADA` de hoy. Con la CI del propio funcionario responde `403 CONFLICTO_DE_INTERES` ya en la búsqueda, no recién al marcar (CU 3.3.4, paso 3).

### 7.2 Contradicciones entre documentos

Regla: si dos documentos se contradicen, gana el requerimiento, y se avisa en el PR.

| # | Contradicción | Cómo se resolvió |
|---|---|---|
| C1 | CU 3.1.1 (flujo 6.A) muestra un mensaje distinto cuando la cuenta está inactiva. RF-01, RNF-10 y S01 exigen que la respuesta no revele qué dato falló ni confirme la existencia de la cuenta. | Gana RF-01 / RNF-10: cuenta inactiva, inexistente o pendiente reciben el mismo `401 CREDENCIALES_INVALIDAS`. |
| C2 | Arquitectura 7.4 dice `404` para un recurso "inexistente o ajeno". Diseño 4.5 dice `403` para "propiedad del recurso no autorizado" y `404` solo si procede. S14 dice `403` para "médico no autorizado". Ningún RF fija el status. | Sin requerimiento que decida, se adopta lo más conservador (no confirmar que el recurso existe, RNF-10): `404 NO_ENCONTRADO` para recursos ajenos. `403` queda para el rol (`SIN_PERMISO`) y el conflicto de interés. Pasa a Preguntas abiertas (P-10). |
| C3 | S16 dice que se recibe "el identificador de especialidad"; la firma 2.3 es `crear(nombre, requierePase)`. | Gana la firma 2.3 (nombre y `requierePase`); el `id` lo genera el servidor. |

## 8. Fuera de este contrato

No están acá porque quedan fuera de los RF pedidos para las semanas 1 y 2. Cada uno necesitará su propio endpoint cuando se agende.

RF-04 cambio de contraseña, RF-05 recuperación de contraseña (el correo de RF-02 para una cuenta ya activa remite a ella), RF-06 edición de datos personales, RF-07 y RF-28 cartelera de novedades, RF-19 cancelación por el funcionario (`cancelarPorFuncionario`, S24), RF-20 modificación de turno semanal, RF-22 historia clínica previa del médico, RF-25 y RF-26 atenciones y pases del médico, RF-27 cancelación por el médico (`cancelarPorMedico`, S25), RF-30, RF-32 y RF-34 cargas masivas, RF-36 y RF-37 consulta de especialidades y consultorios con filtros, RF-38 corrección de datos, RF-42 a RF-44 estadísticas adicionales, RF-45 inactivación y reactivación de empleados.

## 9. Preguntas abiertas

Todo lo que los requerimientos, los casos de uso y el Diseño no resuelven. **No se decidió ninguna.** Quien haga el backend las responde, y la respuesta se vuelca en este contrato y en `endpoints-usados.md`. Entre paréntesis, el comportamiento conservador que el cliente asume mientras tanto.

| # | Pregunta | Dónde afecta | Mientras tanto el cliente… |
|---|---|---|---|
| P-01 | El error uniforme es solo `{code, message}`. ¿Cómo se informa **qué campo** falló en un formulario (400) y **qué fechas y números** chocan en un solapamiento (CU 3.3.1, 7.A.2: "informa las fechas y números en conflicto")? | #11, #13, #25 y todos los formularios | muestra el `message` completo en un aviso general, sin marcar campos. |
| P-02 | La protección CSRF de `refresh` y `logout` (arquitectura 8.3) no define el mecanismo: ¿qué cabecera, cómo la obtiene el cliente, cómo la gestiona Android? Tampoco el nombre ni el `Path` de la cookie. | #2, #3 | no envía nada especial. |
| P-03 | RF-01 no define límite de intentos fallidos ni bloqueo temporal de login. | #1 | no asume ninguno. |
| P-04 | El primer ingreso (CU 3.1.2, pasos 8 y 9) valida el enlace y **muestra el correo registrado, no editable**, antes de pedir los datos. El Diseño 2.3 solo tiene `activar(token, datos, clave)`: no hay operación para validar el enlace ni leer el correo. Tampoco se define a qué ruta del cliente apunta el enlace ni cómo viaja el token. | #5 | muestra el formulario sin el correo y valida el enlace recién al enviar. |
| P-05 | ¿El backend puede distinguir en el mensaje de #5 una cuenta inactivada de un enlace vencido? Hoy van con el mismo código, y el aviso "pedí uno nuevo" no ayuda a una cuenta inactivada. | #5 | muestra el mensaje único. |
| P-06 | Después de #5, ¿el cliente debe quedar con sesión iniciada o volver al login? CU 3.1.2 paso 12 dice "invita a iniciar sesión". | #5 | vuelve al login. |
| P-07 | Si la especialidad requiere pase y el pedido de #17 no trae `paseId`: ¿el servidor busca el pase usable del socio (RF-09: "el sistema verifica que el socio tenga un pase") o rechaza? | #17 | siempre envía `paseId` cuando conoce el pase. |
| P-08 | ¿Cómo conoce el socio sus pases disponibles **antes** de agendar? No hay endpoint que los liste; solo aparecen dentro de una atención (#22). RF-24 impide tener dos disponibles para la misma especialidad. | #16, #17, #22 | los saca de #22 y ofrece el pase `DISPONIBLE` de la especialidad. |
| P-09 | RF-10 y RF-19 fijan reglas de cancelación (2 horas, sin llegada) con parámetros del servidor. ¿El `ConsultaDTO` debe indicar si la consulta puede cancelarse (por ejemplo un booleano), o el cliente intenta y reacciona al `409`? | #18, #19, #20 | ofrece cancelar solo las `AGENDADA` y reacciona a los `409`. |
| P-10 | Status para un recurso de otra persona (consulta, atención, turno): `404` o `403` (contradicción C2). | #19, #20, #22, #30, #31 | trata ambos como "no disponible" con el mismo mensaje. |
| P-11 | Paginación: `HistoriaDTO` (#21) no declara `Page<>`; la disponibilidad (#16) y las consultas de hoy son `List<>` sin tope. ¿Se pagina #16 y #21? ¿Cuál es el máximo de resultados de #16 (30 días × todos los médicos)? | #16, #21, #26 | asume los listados tal como figuran arriba. |
| P-12 | RF-14 y RF-15 permiten suspender o rehabilitar "todos los turnos del rango". ¿`ids` vacío significa todos, o el cliente debe enviar todos los ids (y entonces tener todas las páginas de #15)? | #23, #24, #25 | exige `ids` con al menos un valor y solo opera sobre lo que el funcionario ve y selecciona. |
| P-13 | Estadísticas: ¿"cada turno" de RF-40 es el patrón semanal o la fecha concreta? ¿El porcentaje es 0 a 100 o 0 a 1? ¿La unidad de "Sin datos" es `null`? | #34, #35, #36 | usa 0 a 100 y `null` como "Sin datos". |
| P-14 | Notificaciones: ¿hay estado leído/no leído y cómo se marca (RF y modelo de datos no lo definen)? ¿Se listan los recordatorios aún no vencidos (`programada_para` futuro)? ¿Cuánto tiempo se conservan? ¿Se da de baja el token push al cerrar sesión o cuando otro socio inicia sesión en el mismo dispositivo (`token` es único)? RNF-24 habla de push en Android; ¿vale también el push web? | #32, #33 | lista todo sin estado de lectura; no da de baja el token. |
| P-15 | RF-16 pide mostrar las consultas del día para confirmar al socio. ¿Se debe mostrar también su nombre y apellido para verificar que es la persona correcta? `List<ConsultaDTO>` no los trae. | #26 | muestra solo las consultas. |
| P-16 | ¿Qué médicos lista #10: solo activos (RF-13), o también inactivos para filtrar turnos históricos o suspendidos (RF-17, RF-45)? ¿Un socio ve a todos los médicos activos o solo a los que tienen números ofrecidos? | #10, #15, #16 | muestra solo médicos activos. |
| P-17 | Formato de la CI en el cable: solo dígitos (propuesta) o con puntos y guion. ¿Quién normaliza? | #1, #4, #11, #26, #27, #28 | envía solo dígitos. |
| P-18 | Longitud máxima de los textos libres: afección, tratamiento, observaciones, observación de la suspensión, dirección. Ningún documento la fija. | #5, #24, #31 | no limita más que lo razonable en pantalla. |
| P-19 | Valores por defecto y máximos de `size`. | todos los listados paginados | usa 20 y máximo 100. |
| P-20 | Duración y vigencia del JWT del lado del cliente: ¿se incluye `expiresIn` en la respuesta de sesión? Hoy el cliente solo conoce los 15 minutos por arquitectura 8.3. | #1, #2 | renueva ante el primer `401`. |
| P-21 | ¿Se aplican las mismas reglas de tiempo de respuesta al login para cuentas inexistentes y existentes (para que el tiempo no revele nada)? Es una exigencia de implementación, no de interfaz. | #1 | no depende de eso. |
| P-22 | La respuesta de sesión usa `role` por compatibilidad con el cliente actual, el resto usa `rol` (como las RF). ¿Se unifica? | #1, #2 | lee `role` en la sesión. |
