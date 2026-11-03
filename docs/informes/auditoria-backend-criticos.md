# Auditoría del backend crítico — Proyecto 2026

## 1. Alcance, fuentes y criterio

Auditoría del backend en `integracion/proyecto-2026-avances`, commit
`280a7e4ad5426d243cd8dd233e47193d2af98729` (HEAD local igual a
`origin/integracion/proyecto-2026-avances`; árbol limpio al iniciar la revisión).
El alcance se limita a los 22 RF críticos y sus condiciones de aceptación; no
evalúa los otros 23 RF ni cambia código, esquema, API, configuración de Railway,
ni datos.

Se leyó íntegramente la especificación crítica provista como adjunto en la
conversación. La ruta `docs/especificaciones/backend_criticos_2026.md` no existe
en el checkout, por lo que ese adjunto no puede citarse mediante un archivo
versionado. Se contrastó con la fuente de requerimientos del repositorio,
`docs/analisis/requerimientos.md`, y con `docs/analisis/casos-de-uso.md`,
`docs/analisis/diseno.md`, `docs/api/endpoints-usados.md`, `database/schema.sql`
y el código y las pruebas del backend.

### Estados utilizados

- **COMPLETO EN CÓDIGO:** hay implementación trazable para el alcance descrito
  y pruebas automatizadas relevantes en el repositorio. No significa que se
  haya aceptado en producción ni que se haya ejecutado E2E con PostgreSQL en
  esta auditoría.
- **PARCIAL:** hay flujo implementado, pero se verificó una condición de
  aceptación incumplida o queda una brecha funcional concreta.
- **PENDIENTE:** no se encontró implementación backend funcional verificable.
- **NO VERIFICABLE:** evidencia insuficiente para decidir. No se asigna este
  estado a ningún RF de la matriz; las limitaciones de ambiente se describen
  aparte y no se confunden con ausencia de código.

### Niveles de evidencia de prueba

- **Unitarias:** servicios o utilidades aisladas.
- **Repositorio/mock:** SQL, parámetros y ramas de persistencia comprobados con
  dependencias mockeadas; no ejecutan SQL contra PostgreSQL.
- **HTTP/contexto:** pruebas de controladores, seguridad o contexto Spring;
  pueden usar servicios o repositorios mockeados.
- **PostgreSQL/HTTP real:** pruebas `*IT` con servidor HTTP y PostgreSQL
  descartable; están en el repositorio, pero no se ejecutaron en esta auditoría.
- **E2E frontend:** recorrido desde navegador/cliente real contra un backend y
  base de datos; no ejecutado.

## 2. Resumen ejecutivo

| Estado | Cantidad | Porcentaje de los 22 RF |
|---|---:|---:|
| COMPLETO EN CÓDIGO | 19 | 86,4 % |
| PARCIAL | 0 | 0 % |
| PENDIENTE | 3 | 13,6 % |
| NO VERIFICABLE | 0 | 0 % |

El porcentaje indica únicamente cobertura de implementación y evidencia
automatizada a nivel de código. No es porcentaje de aceptación E2E ni de
validación PostgreSQL. La actualización de RF-02 corresponde al candidato
`feat/rf-02-primer-ingreso` (`5799639d701a8036a1c3943918cc2dfe051cfd32`),
que todavía no está integrado en `integracion/proyecto-2026-avances`.

Hallazgos prioritarios:

1. **RF-39, RF-40 y RF-41 pendientes:** no se encontraron controladores,
   servicios, repositorios, DTO ni SQL de estadísticas. En el catálogo de API
   las rutas estadísticas aparecen como propuestas, no como endpoints
   implementados.
2. **PostgreSQL real no validado para RF-02:** existen pruebas `*IT`
   que usan PostgreSQL, servidor HTTP y una base marcada como descartable,
   pero no fue posible ejecutarlas por falta de PostgreSQL aislado disponible.
   El candidato RF-02 obtuvo **15/15 pruebas focalizadas** y **343/343 en
   `.\mvnw.cmd -B verify`**; esos resultados no incluyen las clases `*IT` ni
   acreditan PostgreSQL o E2E.

## 3. Matriz de los 22 RF críticos

| RF | Requerimiento | Estado | Evidencia de implementación (archivo, clase/método y líneas) | Evidencia / límite de pruebas |
|---|---|---|---|---|
| 01 | Inicio de sesión | **COMPLETO EN CÓDIGO** | `AuthController.login` (línea 34), `AuthService.login` (34), reglas de rutas y roles en `config/SecurityConfig.java` (79 en adelante), sesión/JWT en `auth`. | `AuthServiceTest`, `AuthControllerTest`, `AuthSeguridadTest`; también `integracion/AutenticacionIT` (46 en adelante), no ejecutado como `*IT`. No acredita una validación E2E desplegada. |
| 02 | Primer ingreso | **COMPLETO EN CÓDIGO (CANDIDATO; NO INTEGRADO)** | En `feat/rf-02-primer-ingreso`, `auth/PrimerIngresoService.solicitar` y `completar`; consultas y activación condicional en `auth/PrimerIngresoRepository`; correos post-commit en `PrimerIngresoMailListener`. La cuenta activa conserva respuesta genérica y genera correo de orientación a RF-05 sin crear enlace ni cambiar cuenta. | 15 pruebas unitarias focalizadas y 343 pruebas en `verify` aprobadas. `AutenticacionIT` contiene escenarios HTTP/PostgreSQL para activación, reuso, vencimiento, inactivación y concurrencia, pero no fue ejecutada. Integración bloqueada hasta validar con PostgreSQL aislado. Ver §4. |
| 08 | Consulta de disponibilidad | **COMPLETO EN CÓDIGO** | `agenda/DisponibilidadController.consultar` (18), servicio de agenda y repositorio de disponibilidad; rutas aseguradas como SOCIO en `SecurityConfig`. | Pruebas de servicio/repositorio y `DisponibilidadSeguridadTest` (32 en adelante). Las pruebas de repositorio no sustituyen ejecución SQL real ni verificación E2E de fechas, suspensiones y anticipación. |
| 09 | Agenda de consulta | **COMPLETO EN CÓDIGO** | `agenda/ConsultaService.agendar` (21), `ConsultaRepository.crear` (313), transacción y bloqueos/validaciones en el servicio. Índices únicos parciales sobre número y pase no cancelados: `database/schema.sql` (420–423). | `ConsultaServiceTest`, `ConsultaRepositoryTest`, `ConsultaSeguridadTest`; escenarios reales HTTP/PostgreSQL existen en IT y no se ejecutaron. |
| 11 | Histórico de agendas | **COMPLETO EN CÓDIGO** | `agenda/ConsultaHistorialService.listar` (36), `obtener` (85), consulta filtrada por socio en `ConsultaRepository.HISTORIAL_CTE` (línea 17 en adelante); controller `ConsultaController`. Estados derivados de fin de día en SQL. | Pruebas unitarias, SQL mockeado y HTTP/seguridad en `ConsultaSeguridadTest`; las pruebas `*IT` no fueron ejecutadas. |
| 12 | Historia clínica | **COMPLETO EN CÓDIGO** | `atencion/HistoriaClinicaController.listar` (24) y `detalle` (47); `HistoriaClinicaService.listar` (20), `detalle` (71); `HistoriaClinicaRepository.listar` (25) y `obtenerDetalle` (138). El ID del socio viene del JWT y la consulta del detalle recibe socio e idAtencion. | `HistoriaClinicaServiceTest`, `HistoriaClinicaRepositoryTest`, `HistoriaClinicaSeguridadTest`; mocks/HTTP, no PostgreSQL ejecutado. La propiedad queda implementada en el predicado SQL, pero no se comprobó en esta ejecución contra registros de dos socios en DB real. |
| 13 | Alta de turno semanal | **COMPLETO EN CÓDIGO** | `turno/TurnoSemanalController.crear` (25), `TurnoSemanalService.crear` (38); valida médico activo, especialidad y solapamientos antes de persistir. `GET /api/medicos` es soporte del selector y no prueba por sí solo RF-13. | `TurnoSemanalServiceTest` y `TurnoSemanalSeguridadTest` verifican reglas y rol FUNCIONARIO. Hay prueba IT de concurrencia, no ejecutada. |
| 14 | Suspensión de fechas | **COMPLETO EN CÓDIGO** | `turno/TurnoFechasController` (líneas 27–35), `TurnoFechasService.suspender` (65); cancelación transaccional de consultas y registro de evento. | `TurnoFechasServiceTest`, `TurnoFechasRepositoryTest`, `TurnoFechasSeguridadTest`; pruebas unitarias/mock y HTTP de seguridad. IT de concurrencia no ejecutada. |
| 15 | Rehabilitación de fechas | **COMPLETO EN CÓDIGO** | `TurnoFechasController.rehabilitar` (42), `TurnoFechasService.rehabilitar` (152); verifica vigencia del médico y conflictos de médico/consultorio; no restaura reservas canceladas. | Pruebas de servicio/repositorio y seguridad; IT de concurrencia no ejecutada. |
| 16 | Aviso de llegada | **COMPLETO EN CÓDIGO** | `aviso/AvisoLlegadaService.consultasDeHoy` (32) y `registrar` (41); controller GET/POST en `AvisoLlegadaController` (29/36); persistencia incluye funcionario y hora. | Pruebas unitarias, repositorio y `AvisoLlegadaSeguridadTest`; recorrido real está en ITs no ejecutadas. |
| 17 | Consulta de turnos | **COMPLETO EN CÓDIGO** | `turno/TurnoConsultaController.listar` (18), `TurnoConsultaService.listar` (20), `TurnoConsultaRepository.listar` (50); ruta `GET /api/turnos` y consulta de patrón semanal. | `TurnoConsultaServiceTest`, `TurnoConsultaRepositoryTest`, `TurnoConsultaSeguridadTest`; mocks/HTTP, sin PostgreSQL real ejecutado. |
| 18 | Consulta de agendas | **COMPLETO EN CÓDIGO** | `agenda/AgendaConsultaController.consultar` (18), `AgendaConsultaService.consultar` (40), SQL y estados derivados en `AgendaConsultaRepository` (CTE desde línea 16). | Pruebas de servicio, SQL mockeado y `AgendaConsultaSeguridadTest`; escenarios HTTP/PostgreSQL reales no ejecutados. |
| 21 | Turnos y pacientes de una fecha | **COMPLETO EN CÓDIGO** | `turno/TurnoMedicoController` (24 en adelante), `TurnoMedicoService.listar` (33), repositorio filtra por médico del JWT y fecha. | `TurnoMedicoServiceTest`, `TurnoMedicoRepositoryTest`, `TurnoMedicoSeguridadTest`; IT de llegada/resultado no ejecutada. |
| 23 | Registro del resultado de consulta | **COMPLETO EN CÓDIGO** | `atencion/AtencionController.registrarResultado` (22), `AtencionService.registrarResultado` (37). Verifica médico/consulta, conflicto de interés, estado, fecha y aviso; atiende o marca `NO_SE_PRESENTO` dentro de transacción. | `AtencionServiceTest`, `AtencionRepositoryTest`, `AtencionSeguridadTest`; IT `LlegadaAgendaMedicoIT` prueba flujos y no se ejecutó. |
| 24 | Registro de pases | **COMPLETO EN CÓDIGO** | Emisión acoplada al alta de atención en `AtencionService` (método desde 37; validación de pases más adelante), persistencia `AtencionRepository.crearPase` (202). `PaseController` expone disponibles. | Unitarias de servicio/repositorio y seguridad. Reglas de exclusividad/vigencia y consumo tienen pruebas automatizadas, pero no se ejecutaron con PostgreSQL real en esta auditoría. |
| 29 | Alta individual de especialidades | **COMPLETO EN CÓDIGO** | `especialidad/EspecialidadController` (26/31), `EspecialidadService.listar/crear` (20/24), repositorio; autorización ADMINISTRADOR. `schema.sql` define unicidad case-insensitive (419). | `EspecialidadServiceTest`, `EspecialidadControllerTest`, `EspecialidadSeguridadTest`; DB real no ejecutada. |
| 31 | Alta individual de usuarios | **COMPLETO EN CÓDIGO** | `usuario/AltaUsuarioController.crear` (38), `AltaUsuarioService.crear` (35), repositorio/cuenta-persona y validación de CI/roles/especialidades. | `AltaUsuarioServiceTest`, `AltaUsuarioSeguridadTest`, controladores y guardas de integración; no equivale a ejecución PostgreSQL en esta auditoría. |
| 33 | Alta individual de consultorios | **COMPLETO EN CÓDIGO** | `consultorio/ConsultorioController.crear` (30), `ConsultorioService.crear` (24), repositorio; autorización ADMINISTRADOR. | Pruebas unitarias, controller y seguridad; no se ejecutó contra PostgreSQL real. |
| 35 | Consulta del padrón | **COMPLETO EN CÓDIGO** | `usuario/AltaUsuarioController.listar` (27), `UsuarioService.listar` (17), `UsuarioPadronRepository.listar` (19); el DTO es por cuenta y excluye credenciales. | `UsuarioServiceTest`, `UsuarioRepositoryTest`, `AltaUsuarioSeguridadTest`; SQL mockeado y HTTP de roles, sin PostgreSQL real ejecutado. |
| 39 | Estadísticas por especialidad | **PENDIENTE** | No se encontraron endpoint/controller, servicio, repositorio, DTO ni consulta SQL de estadísticas. `docs/api/endpoints-usados.md` clasifica las rutas de estadísticas como propuesta. | No se encontraron tests funcionales del RF. No existe resultado PostgreSQL/HTTP ni E2E. |
| 40 | Estadísticas por turno | **PENDIENTE** | No hay implementación de porcentaje de números ocupados sobre ofrecidos en fechas activas; no se encontraron endpoint, servicio, SQL o DTO estadístico. | No se encontraron tests funcionales del RF. La regla debe distinguir estados que ocupan el número, cancelaciones y fechas suspendidas. |
| 41 | Estadísticas de consultas | **PENDIENTE** | No se encontraron endpoint, servicio, consulta SQL ni DTO que agregue cantidades por estado y tasa de cancelación del socio. | No se encontraron tests funcionales del RF. No hay evidencia de manejo de total cero como “Sin datos” frente a numerador cero como 0 %. |

Los números de línea son del commit auditado; enlaces y nombres de clases se
refieren a rutas relativas desde la raíz del repositorio.

## 4. Análisis exhaustivo de RF-02 — Primer ingreso

### Reglas que sí aparecen implementadas

- `PrimerIngresoService.solicitar` rechaza campos faltantes, acepta solo
  accesos `SOCIO` o `EMPLEADO` y normaliza/valida la CI uruguaya antes de
  consultar.
- `PrimerIngresoRepository.buscarCuentaPendiente` filtra por CI, cuenta
  habilitada y primer ingreso no completado. El acceso SOCIO selecciona solo
  SOCIO; EMPLEADO cubre FUNCIONARIO, MEDICO y ADMINISTRADOR. La fila se bloquea
  con `FOR UPDATE OF c`.
- Para una cuenta pendiente, se invalidan enlaces de primer ingreso anteriores,
  se genera token aleatorio de 32 bytes, se almacena SHA-256 y se establece
  vencimiento UTC a 24 horas. El evento de correo se publica dentro de la
  transacción y `PrimerIngresoMailListener` lo procesa tras el commit.
- La activación actualiza enlace y cuenta bajo `@Transactional`; el SQL exige
  enlace correcto, no usado, no vencido, cuenta habilitada y primer ingreso
  pendiente. La cuenta se vuelve a comprobar en el `UPDATE` final. El correo
  registrado no se modifica.
- Se requiere dirección, teléfono 1 y contraseña; se valida longitud mínima y
  límite de 72 bytes UTF-8 correspondiente al encoder BCrypt usado por el
  backend. La contraseña se persiste codificada.
- Respuestas de enlace inválido, usado, vencido y cuenta inactiva se unifican.
  El listener no registra token ni correo; ante una excepción registra id de
  cuenta y clase de excepción.
- `AutenticacionIT` contempla activación satisfactoria y login posterior,
  token no almacenado en claro, enlace inventado/reutilizado/expirado y
  respuesta genérica.

### Estado del candidato RF-02

El candidato `5799639d701a8036a1c3943918cc2dfe051cfd32` corrige la discrepancia
funcional: cuenta activa e inexistente reciben el mismo cuerpo HTTP genérico;
para la cuenta activa se programa un correo que explica que ya está activa y
orienta al flujo RF-05. No se crea un enlace de primer ingreso ni se cambia
contraseña, correo o estado de la cuenta.

El token se genera aleatoriamente, se persiste como hash, vence a las 24 horas
por configuración predeterminada y el consumo se realiza con actualización
condicional dentro de una transacción. La consulta y la actualización final
comprueban que la cuenta siga habilitada y pendiente. La carrera de dos
consumidores tiene una IT definida, pero todavía no se ha ejecutado contra
PostgreSQL; por eso la garantía de concurrencia queda pendiente de validación
real antes de integrar.

### Casos con prueba real escrita, pendiente de ejecución

- Inactivar administrativamente una cuenta después de emitir el enlace y
  verificar que el enlace no la reactive.
- Intentos concurrentes de completar el mismo enlace; solo uno puede activar.
- Repetir solicitud para asegurar que solo el enlace nuevo sea válido.
- Probar ambos accesos (SOCIO/EMPLEADO) con cuentas homónimas de persona,
  diferenciando cuenta SOCIO de cuenta de empleado.
- Confirmar el flujo de evento transaccional y la entrega/fallo del proveedor
  de correo sin exponer token/correo. Las pruebas unitarias del listener cubren
  el contenido y el logging, pero no sustituyen la integración del listener
  con el commit transaccional.

## 5. Análisis exhaustivo de RF-39, RF-40 y RF-41

No es una carencia de pruebas únicamente: falta la funcionalidad de servidor.
No hay rutas estadísticas implementadas ni autorización específica asociada
con consultas de estadísticas para ADMINISTRADOR.

- **RF-39:** debe agregar por especialidad las consultas según fecha de
  agendamiento, incluyendo las que después se cancelaron. El campo persistido
  relevante es `consulta.agendada_en`; no debe filtrar solamente reservas
  actualmente activas.
- **RF-40:** debe agregar números ofrecidos y ocupados para las fechas del
  período en que el turno estuvo activo. La definición de ocupado incluye
  AGENDADA, ATENDIDA, NO_ASISTIO, NO_ATENDIDA y NO_SE_PRESENTO_A_LA_CONSULTA;
  las cancelaciones dejan el número libre. Los estados NO_ASISTIO y
  NO_ATENDIDA se derivan por fecha y aviso de llegada en las consultas
  operativas (`ConsultaRepository` y `AgendaConsultaRepository`); no son
  estados persistidos por `consulta`.
- **RF-41:** debe contar por fecha del turno/consulta y estado, incluyendo
  canceladas por socio e institución, y calcular tasa de cancelación por socio.
  Debe distinguir total cero (“Sin datos”) de total positivo y cero
  cancelaciones (0 %).

El esquema guarda como estados principales `AGENDADA`, `ATENDIDA`,
`CANCELADA_SOCIO`, `CANCELADA_INSTITUCION` y `NO_SE_PRESENTO` en
`database/schema.sql` (242–290). Los dos estados derivados requieren una
política temporal coherente en la agregación estadística. La fecha para RF-39
es `agendada_en`; para RF-40/RF-41, la fecha de la consulta/turno, de acuerdo
con la fuente de requerimientos.

## 6. Calidad y alcance de las pruebas

- Para el commit inicial auditado (`280a7e4`), la suite Maven registrada fue
  `.\mvnw.cmd -B verify`: 338 aprobados, 0 fallidos, 0 errores, 0 omitidos.
  Para el candidato RF-02 (`5799639`), se informaron 15/15 pruebas focalizadas
  y 343/343 en `verify`. La configuración de la suite normal evitó conectar
  a `localhost:5432`; ninguno de esos resultados acredita PostgreSQL.
- `backend/api/pom.xml` configura `maven-surefire-plugin` y no configura
  `maven-failsafe-plugin`. Por convención, las clases `*IT` no están incluidas
  en la ejecución ordinaria Surefire/`verify`.
- Las pruebas reales sí están preparadas en
  `backend/api/src/test/java/.../integracion`: `BaseIntegracionIT` levanta un
  servidor HTTP y usa PostgreSQL, pero exige una base local con sufijo
  `_e2e`/`_test` y una marca/variable de habilitación antes de ejecutar
  operaciones destructivas sobre su esquema. Esta protección no autoriza
  ejecutar pruebas en una base desconocida.
- No se ejecutó ni se validó una base PostgreSQL durante esta auditoría.
  Tampoco se ejecutó un navegador/frontend contra un backend real. Por tanto,
  no se reporta aprobación E2E, ni se concluye funcionamiento en Railway.

## 7. Contradicciones documentales identificadas

1. El archivo versionado bajo `docs/especificaciones/` no está presente; la
   especificación crítica se recibió como adjunto y fue leída. Para poder
   auditarla en futuras ejecuciones conviene incorporarla al repositorio sin
   alterar su contenido oficial.
2. `docs/api/endpoints-usados.md` conserva estadísticas como propuestas, en
   concordancia con la ausencia de implementación actual; esos textos no son
   evidencia de endpoints disponibles.

## 8. Conclusión

El código compartido auditado inicialmente tenía implementación significativa
para 18 de los 22 RF críticos. El candidato no integrado de RF-02 eleva a 19 la
cobertura de código con pruebas automatizadas, pero aún no tiene validación IT
con PostgreSQL ni E2E. RF-39, RF-40 y RF-41 siguen pendientes. No se deben
presentar las tres estadísticas como funcionalidades existentes ni afirmar
que RF-02 fue integrado o validado con PostgreSQL hasta completar esa etapa.

El plan de cierre y dependencias está en
[`pendientes-criticos.md`](./pendientes-criticos.md).
