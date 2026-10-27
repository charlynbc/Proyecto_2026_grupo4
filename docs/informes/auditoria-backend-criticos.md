# Auditoría del backend crítico — Proyecto 2026

## 1. Alcance y método

Este documento audita la implementación real de la rama `integracion/proyecto-2026-avances` contra los 22 requerimientos críticos del proyecto, tal como se exponen en la documentación del repositorio y en la implementación del backend.

### Fuente canónica tomada en este repositorio

- `docs/analisis/requerimientos.md`
- `docs/analisis/arquitectura.md`
- `docs/api/endpoints-usados.md`
- `database/schema.sql`
- `backend/api/src/main/java/...` (código real del backend)

### Contradicción documental importante

La especificación solicitada por la instrucción, `docs/especificaciones/backend_criticos_2026.md`, no existe en este repositorio. No fue posible leer ese archivo en esta ejecución. Por eso, la auditoría se basó en la fuente disponible y canónica del proyecto en `docs/analisis/requerimientos.md`, y se registró explícitamente esta discrepancia para evitar sustituir una regla no disponible por supuestos del auditor.

Se mantiene la regla de no inventar requisitos ni endpoints: solo se documenta lo que existe y está verificado en el código real.

## 2. Resumen ejecutivo

La rama `integracion/proyecto-2026-avances` contiene un backend Spring Boot real y con estructura coherente para la operación del sistema: seguridad por JWT, Spring Security, PostgreSQL, lógica de negocio modularizada, registro de usuarios/turnos/especialidades/consultas y operaciones administrativas. Hay evidencia concreta de implementación de varios RF críticos.

Sin embargo, la auditoría no permite afirmar que los 22 RF críticos estén cerrados de manera verificable en producción o con PostgreSQL real, porque:

- no existe un archivo de especificación de RF crítico en la ruta indicada;
- la validación real del backend no se ejecutó sobre un PostgreSQL del entorno de pruebas del proyecto, sino sobre la suite unitaria/mocked del repositorio;
- varios requerimientos críticos implican reglas de negocio complejas (inactivación, conflicto de interés, cancelaciones, pases, estados derivados, trazabilidad), y la evidencia del código no siempre demuestra la validación E2E completa de cada una de esas reglas.

## 3. Matriz de los 22 RF críticos

| RF | Requerimiento | Evidencia real | Estado auditado | Observación |
|---|---|---|---|---|
| RF-01 | Inicio de sesión | `AuthController`, `AuthService`, `JwtService`, `SecurityConfig` | Implementado en código | El flujo real de login con acceso SOCIO/EMPLEADO y JWT está presente. |
| RF-02 | Primer ingreso | `PrimerIngresoController`, `PrimerIngresoService`, `CuentaRepository`, `enlace_cuenta` en `schema.sql` | Parcial / no verificado E2E | Existe flujo de activación, token y validación, pero requiere revisión de inactivación administrativa y de caso límite con reutilización/expiración. |
| RF-08 | Consulta de disponibilidad | `DisponibilidadController`, `AgendaService`, `FiltroDisponibilidadDTO` | Implementado en código | La API de disponibilidad y filtrado existe. Falta validación histórica real con PostgreSQL para la regla completa de pases, suspensión y anticipación. |
| RF-09 | Agenda de consulta | `ConsultaController`, `ConsultaService`, `CrearConsultaRequest` | Implementado en código | La reserva existe y consume pases/valida reglas en servicio. Es una de las piezas clave del core del sistema. |
| RF-11 | Histórico de agendas | `ConsultaController`, `ConsultaHistorialService`, `ConsultaHistorialPageResponse` | Implementado en código | El historial del socio existe con filtros y paginación. |
| RF-12 | Consulta de historia clínica | `HistoriaClinicaController`, `HistoriaClinicaService`, `HistoriaClinicaRepository`, `AtencionService` | Implementado en la rama de trabajo; sin E2E PostgreSQL | La lista y el detalle derivan el socio del JWT; el detalle filtra por socio e ID en SQL. Hay pruebas unitarias, HTTP/seguridad y comprobaciones de SQL con mocks; no equivalen a una prueba real de propiedad contra PostgreSQL. |
| RF-13 | Alta de turno semanal | `TurnoSemanalController`, `TurnoSemanalService`, `turno_semanal` en `schema.sql`; `GET /api/medicos` como selector | Implementado en código; selector añadido | La configuración semanal y los números existen en modelo y servicio. `GET /api/medicos` es soporte para seleccionar médicos habilitados, no demuestra por sí mismo que RF-13 completo esté cerrado. |
| RF-14 | Suspensión de fechas de turno | `TurnoFechasController`, `TurnoFechasService`, `SuspenderFechasRequest` | Implementado en código | La suspensión tiene servicio y API. Faltan pruebas reales concretas contra reglas de cancelación, devolución de pases y observación. |
| RF-15 | Rehabilitación de fechas de turno | `TurnoFechasController`, `TurnoFechasService`, `RehabilitarFechasRequest` | Implementado en código | Existe flujo de restauración de fechas suspendidas. |
| RF-16 | Registro de aviso de llegada | `AvisoLlegadaController`, `AvisoLlegadaService`, `AvisoLlegadaRepository` | Implementado en código | El aviso de llegada existe y se almacena con funcionario/hora. Falta verificación de conflicto de interés y unicidad por socio/día con PostgreSQL real. |
| RF-17 | Consulta de turnos | `TurnoConsultaController`, `TurnoConsultaService` | Implementado en código | La consulta de fechas concretas y estado de turnos existe. |
| RF-18 | Consulta de agendas | `AgendaConsultaController`, `AgendaConsultaService` | Implementado en código | La pantalla de seguimiento del funcionario está presente. |
| RF-21 | Turnos y pacientes de una fecha | `TurnoMedicoController`, `TurnoMedicoService`, `ResultadoConsulta...` | Implementado en código | La vista de pacientes por turno y fecha existe; requiere validación real del orden, llegada y conflicto de interés. |
| RF-23 | Registro del resultado de la consulta | `AtencionController`, `AtencionService`, `ResultadoConsultaRequest` | Implementado en código | Es un flujo central. Existe atención/no asistió/no se presentó. No hay evidencia de validación sobre todos los casos alternativos y transacciones. |
| RF-24 | Registro de pases | `PaseController`, `PaseService`, `PaseDTO` | Implementado en código | La API y el modelo del pase existen. Faltan comprobaciones reales de vigencia, uso y exclusividad en escenarios complejos. |
| RF-29 | Alta individual de especialidades | `EspecialidadController`, `EspecialidadService`, `Especialidad` | Implementado en código | El alta existe y está protegida por rol. |
| RF-31 | Alta individual de usuarios | `AltaUsuarioController`, `AltaUsuarioService`, `CuentaRepository`, `persona`/`cuenta` en `schema.sql` | Implementado en código | La carga del padrón y la relación persona/cuenta están presentes. |
| RF-33 | Alta individual de consultorios | `ConsultorioController`, `ConsultorioService`, `consultorio` en `schema.sql` | Implementado en código | Existen alta y servicio del consultorio. |
| RF-35 | Consulta de usuarios | `GET /api/usuarios`, `UsuarioService`, `UsuarioPadronRepository`, DTO de cuenta | Implementado en la rama de trabajo; sin E2E PostgreSQL | Una fila por cuenta, filtros por rol/estado/CI-apellido, paginación y acceso de ADMINISTRADOR. Pruebas unitarias, HTTP/seguridad y SQL mockeado pasan; falta verificación con PostgreSQL real. |
| RF-39 | Estadísticas por especialidad | No se evidencia en código analizado | No verificado / no implementado de forma clara | Requiere revisión específica del módulo administrativo. |
| RF-40 | Estadísticas por turnos | No se evidencia en código analizado | No verificado / no implementado de forma clara | Sin evidencia de endpoint/servicio específico. |
| RF-41 | Estadísticas por consultas | No se evidencia en código analizado | No verificado / no implementado de forma clara | Sin evidencia de endpoint/servicio específico. |

## 4. Cobertura general

### Estado de cobertura

- Criterio 1: “hay código que implementa la funcionalidad”: sí, para la mayoría de los RF críticos.
- Criterio 2: “la regla está validada con PostgreSQL real y con casos de negocio completos”: no está demostrado en esta auditoría.

### Síntesis

La implementación real del backend tiene un volumen considerable de código y una estructura coherente, pero la evidencia del repositorio no demuestra cobertura completa y verificable de todos los 22 RF críticos. El contenido del código sugiere un esfuerzo real de implementación, pero aún no se ha realizado una auditoría de aceptación por requisito con base de datos real y casos de borde.

## 5. Principales problemas detectados

1. Falta de una especificación literal del archivo indicado
   - La ruta `docs/especificaciones/backend_criticos_2026.md` no existe.
   - Esto obliga a trabajar con `docs/analisis/requerimientos.md` como fuente primaria del repositorio, pero no elimina la discrepancia documental.

2. Diferencia entre tests unitarios y validación real
   - La suite Maven posterior a los cambios pasa (338 tests, 0 fallos, 0 errores), pero esta ejecución no equivale a validación end-to-end con PostgreSQL: se configuró una URL intencionalmente inalcanzable para evitar el listener local no identificado en 5432.

3. Reglas de negocio complejas sin prueba real visible
   - Las reglas de pases, cancelaciones, inactivación administrativa, conflicto de interés y estados derivados (`NO_ASISTIO`, `NO_ATENDIDA`, `NO_SE_PRESENTO_A_LA_CONSULTA`) son críticas y requieren validación real, no solo unit tests con mocks.

4. Seguridad y autorización
   - El backend usa JWT y Spring Security, pero la auditoría no revela una verificación exhaustiva de que cada operación apunte a la cuenta correcta en todos los casos de conflicto de interés.

5. Faltan indicadores claros de estadísticas administrativas
   - Los RF-39, RF-40 y RF-41 no tienen evidencia concreta de implementación específica en el backend observado.

## 6. Primer RF crítico que debería completarse

El primer RF crítico a cerrar debería ser RF-01 (inicio de sesión), por estos motivos:

- es la base de acceso al resto del sistema;
- ya está implementado con JWT y roles;
- es el punto de entrada para la validación de permisos y de cuenta activa;
- todas las demás funciones dependen de que este mecanismo se comporte de manera consistente.

No se trata de “mínimo viable” general, sino del punto de entrada que permite validar la autenticación y autorización del resto del flujo.

## 7. Orden recomendado de implementación posterior

1. RF-01 — Inicio de sesión y seguridad de acceso
2. RF-02 — Primer ingreso e inactivación administrativa
3. RF-08 / RF-09 — disponibilidad y agenda del socio
4. RF-16 / RF-18 / RF-21 — llegada y seguimiento por funcionario/médico
5. RF-23 / RF-24 — atención y pases
6. RF-13 / RF-14 / RF-15 — turnos y suspensión/rehabilitación
7. RF-29 / RF-31 / RF-33 — administración de dominio
8. RF-39 / RF-40 / RF-41 — estadísticas

## 8. Conclusión

El backend real del repositorio es una base sólida y funcionalmente avanzada, con componente de seguridad, repositorios, servicios, DTOs y esquema de datos que sostienen la mayor parte del dominio crítico. Sin embargo, la auditoría no permite calificar los 22 RF críticos como “completos” con evidencia verificable de negocio y PostgreSQL real. El trabajo recomendado es cerrar primero la autenticación, luego la inactivación/primera vez, y después los flujos de agenda, atención y pases con pruebas reales.

## 9. Actualización de validación de RF-12, RF-13 y RF-35 — 26/10/2026

La verificación de esta continuación se realizó en la rama de trabajo
`feat/validacion-endpoints-criticos`, creada desde el commit
`0de783b5ca4abd55731b4880d8330644e8bf10f3`. Los cambios no deben interpretarse
como integrados hasta que se confirme el push a avances.

- **RF-12:** se añadieron `GET /api/historia-clinica` y
  `GET /api/historia-clinica/{idAtencion}`. El controlador deriva el socio del
  JWT y la consulta SQL del detalle incluye tanto el socio como el ID de
  atención. Pruebas unitarias, HTTP/roles y composición SQL con `JdbcTemplate`
  mockeado pasan. Falta verificar propiedad y datos/pases con PostgreSQL aislado.
- **RF-35:** `GET /api/usuarios` está protegido para `ADMINISTRADOR`, devuelve
  una fila por cuenta, aplica filtros y paginación, y usa un DTO sin hashes ni
  tokens. Pruebas unitarias, HTTP/roles y composición SQL mockeada pasan. Falta
  verificar resultados contra PostgreSQL aislado.
- **RF-13:** `GET /api/medicos` da soporte al selector de médicos habilitados
  y sus especialidades para el funcionario. Este endpoint por sí solo no
  demuestra que RF-13 esté completo; el alta/validación transaccional de turnos
  semanales requiere su propia evidencia.
- **Suite Maven:** `.\mvnw.cmd -B verify` terminó con 338 tests aprobados,
  0 fallidos, 0 errores y 0 omitidos. Se apuntó deliberadamente a
  `127.0.0.1:1`, un puerto inalcanzable, porque existe un listener no
  identificado en `localhost:5432` y Docker no estaba disponible. El resultado
  valida la suite disponible (unitaria, mock y contexto/HTTP), no una prueba
  real de PostgreSQL ni un E2E con datos.
- **E2E pendiente:** preparar una instancia PostgreSQL efímera o una base de
  pruebas marcada/aislada, ejecutar los flujos de médicos, padrón, historia
  propia, rechazo de historia ajena y pases; confirmar el contrato desde el
  frontend local. No usar datos clínicos reales.
