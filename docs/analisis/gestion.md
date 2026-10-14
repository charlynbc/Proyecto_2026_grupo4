[**1. Introducción 4**](#introducción)

> [1.1. Propósito 4](#propósito)
>
> [1.2. Criterios de gestión 4](#criterios-de-gestión)

[**2. Organización del equipo 5**](#organización-del-equipo)

> [2.1. Definición de roles 5](#definición-de-roles)
>
> [2.2. Organización del trabajo 5](#organización-del-trabajo)

[**3. Planificación y seguimiento de horas 6**](#planificación-y-seguimiento-de-horas)

> [3.1. Criterio de estimación 6](#criterio-de-estimación)
>
> [3.2. Estimación global de horas 6](#estimación-global-de-horas)
>
> [3.3. Registro de horas reales y desvíos 7](#registro-de-horas-reales-y-desvíos)

[**4. Cronograma general 8**](#cronograma-general)

> [4.1. Diagrama de Gantt estimado 8](#diagrama-de-gantt-estimado)
>
> [4.2. Seguimiento del cronograma 8](#seguimiento-del-cronograma)

[**5. Planificación de la implementación 9**](#planificación-de-la-implementación)

> [5.1. Primera iteración 9](#primera-iteración)
>
> [5.2. Segunda iteración 10](#segunda-iteración)

# [1. Introducción](#introducción)

## [1.1. Propósito](#propósito)

El presente documento describe la gestión del proyecto del equipo para el desarrollo del sistema online de reserva de órdenes para una institución de asistencia médica. Su objetivo es establecer la organización interna del equipo, la estimación global de esfuerzo, el cronograma de trabajo y la planificación de la etapa de implementación.

Asimismo, servirá como instrumento de seguimiento. Se registrarán las horas reales dedicadas, los desvíos respecto de la estimación inicial y las decisiones tomadas para ajustar la planificación. Al finalizar se incorporará un segundo diagrama de Gantt que represente la ejecución real y permita compararla con la planificación original.

## 1.2. Criterios de gestión

La planificación toma como referencia una dedicación estimada de 20 horas semanales por integrante. El equipo está integrado por siete personas, por lo que se considera una disponibilidad de 140 horas semanales. Para las 16 semanas previstas, la capacidad total de referencia es de 2.240 horas.

La implementación se organiza en dos iteraciones de dos semanas. La primera se concentra en el circuito principal de agenda, llegada y atención; la segunda completa las funciones complementarias y las estadísticas. Las pruebas funcionales se realizan durante el desarrollo y las demás pruebas se completan en el Mes 4.

El sistema comprende una aplicación web para Socio, Funcionario, Médico y Administrador, y una aplicación Android con todas las funcionalidades del Socio. La planificación se ajusta a los requerimientos y casos de uso del proyecto.

# 2. Organización del equipo

## 2.1. Definición de roles

**Coordinador**: Organiza y supervisa el trabajo del equipo, realiza el seguimiento de la planificación y controla el cumplimiento de objetivos y plazos.

**Backend**: Implementa la lógica de negocio, los servicios, la persistencia y las integraciones del sistema.

**Frontend/Mobile**: Implementa las interfaces web y Android y su comunicación con los servicios del backend.

**Base de datos**: Define y mantiene el modelo de datos, las restricciones y las consultas necesarias para el sistema.

**DevOps**: Configura y mantiene los entornos, repositorios y despliegues utilizados durante el proyecto.

**Tester**: Planifica y ejecuta pruebas, registra resultados e incidencias y verifica las correcciones.

**Documentador**: Organiza, redacta y revisa la documentación del proyecto, manteniendo la consistencia entre los entregables.

## 2.2. Organización del trabajo

Los integrantes pueden desempeñar más de un rol. La organización del trabajo contempla actividades de desarrollo, pruebas, documentación y coordinación, procurando que puedan avanzar en paralelo y dentro de la dedicación prevista.

# 3. Planificación y seguimiento de horas

## 3.1. Criterio de estimación

La estimación se realiza sobre una base de 20 horas semanales por integrante. La distribución por actividad considera el alcance y la complejidad del trabajo, y se ajustará conforme avance el proyecto. Las pruebas de concepto sirven como apoyo para estimar y desarrollar el prototipo, incluyendo las adaptaciones que requieran las funcionalidades.

La capacidad disponible se utiliza como referencia para organizar el trabajo; las horas estimadas expresan el esfuerzo previsto para cada actividad. Las pruebas funcionales realizadas durante el desarrollo forman parte de la implementación del prototipo.

## 3.2. Estimación global de horas

La siguiente tabla presenta la estimación de horas correspondiente a las distintas actividades previstas para el desarrollo del proyecto. Las horas reales se completarán durante la ejecución.

| **Actividad**                     | **Estimadas (h)** | **Reales (h)** |
|-----------------------------------|-------------------|----------------|
| Instancias de monitoreo con tutor | 30                |                |
| Documento de Gestión              | 21                |                |
| Revisión de antecedentes          | 32                |                |
| Documento de Pruebas de Concepto  | 84                |                |
| Documento de Requerimientos       | 83                |                |
| Documento de Casos de Uso         | 75                |                |
| Documento de Arquitectura         | 43                |                |
| Documento de Diseño               | 74                |                |
| Glosario                          | 16                |                |
| Modelo de Dominio                 | 41                |                |
| Modelo de Datos                   | 33                |                |
| Prototipo funcional               | 522               |                |
| Testing                           | 64                |                |
| Informe final y demostración      | 86                |                |
| **Total**                         | **1.204**         |                |

## 3.3. Registro de horas reales y desvíos

Las horas dedicadas se registrarán por actividad y se consolidarán periódicamente. El desvío se calculará como horas reales menos horas estimadas. Cuando exista una diferencia relevante, se documentará su causa y la medida adoptada para ajustar la planificación.

Los registros de actividades anteriores se incorporarán cuando se cuente con información suficiente. Al finalizar el proyecto se compararán las horas estimadas y reales y las fechas previstas y efectivas.

| **Desvío**                                         | **Causa**                                                         | **Medida prevista**                                                                            |
|----------------------------------------------------|-------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| Atraso en entregables de análisis y cierre de POC. | Actividades documentales y de pruebas de concepto aún pendientes. | Priorizar las definiciones necesarias para implementar y completar los documentos en paralelo. |

# 4. Cronograma general

El cronograma se organiza en cuatro meses de cuatro semanas, de acuerdo con la propuesta del proyecto:

- Mes 1 — ago 17, 2026 al sept 14, 2026: investigación, revisión de antecedentes y pruebas de concepto.

- Mes 2 — sept 14, 2026 al oct 12, 2026: análisis, diseño y documentación.

- Mes 3 — oct 12, 2026 al nov 9, 2026: implementación en dos iteraciones y pruebas funcionales.

- Mes 4 — nov 9, 2026 al dic 7, 2026: finalización del testing, informe final y preparación de la defensa.

Se prevé un margen para completar pendientes de implementación durante las primeras dos semanas del Mes 4, en paralelo con las pruebas y la documentación. La entrega final está prevista para el dic 11, 2026.

## 4.1. Diagrama de Gantt estimado

<img src="media/image1.png" style="width:6.26384in;height:3.58431in" />

## 4.2. Seguimiento del cronograma

El avance y los cambios de fechas se registran durante el proyecto. Al finalizar se incorporará el Gantt real y una breve comparación con lo planificado, indicando los principales desvíos y sus causas.

# 5. Planificación de la implementación

La implementación se divide en dos iteraciones de dos semanas. La primera prioriza el circuito operativo completo. Las estadísticas RF-39, RF-40 y RF-41 conservan su clasificación crítica y se cierran al comienzo de la segunda iteración. Su preparación se inicia junto con el circuito principal.

## 5.1. Primera iteración

Del oct 12, 2026 al oct 26, 2026. Se prevé disponer del circuito de agenda, llegada y atención integrado, con las funciones críticas del Socio en web y Android.

### 5.1.1. Semana 1

- Inicio de sesión y primer ingreso (RF-01 y RF-02).

- Consulta de disponibilidad y agenda de consultas (RF-08 y RF-09).

- Alta y consulta de turnos (RF-13 y RF-17).

- Alta individual de especialidades, usuarios y consultorios; consulta de usuarios (RF-29, RF-31, RF-33 y RF-35).

### 5.1.2. Semana 2

- Historial de agendas e historia clínica del Socio (RF-11 y RF-12).

- Suspensión y rehabilitación de turnos (RF-14 y RF-15).

- Registro de aviso de llegada y consulta de agendas (RF-16 y RF-18).

- Consulta de pacientes del turno, registro del resultado y de la atención, y emisión de pases (RF-21, RF-23 y RF-24).

## 5.2. Segunda iteración

Del oct 26, 2026 al nov 9, 2026. Se completan las funciones complementarias y las estadísticas, manteniendo las funcionalidades del Socio en web y Android.

### 5.2.1. Semana 3

- Cierre de sesión, cambio y recuperación de contraseña y datos personales (RF-03, RF-04, RF-05 y RF-06).

- Cancelación de consultas por los distintos actores y modificación del consultorio (RF-10, RF-19, RF-20 y RF-27).

- Consulta de historia clínica previa, atenciones y pases del Médico (RF-22, RF-25 y RF-26).

- Inactivación y reactivación de empleados (RF-45).

- Estadísticas de demanda por especialidad, utilización de turnos y consultas por estado (RF-39, RF-40 y RF-41).

### 5.2.2. Semana 4

- Consulta y publicación en la cartelera de novedades (RF-07 y RF-28).

- Cargas masivas de especialidades, usuarios y consultorios (RF-30, RF-32 y RF-34).

- Consulta de catálogos y corrección de datos (RF-36, RF-37 y RF-38).

- Estadísticas de inasistencia, pases y días y franjas pico (RF-42, RF-43 y RF-44).

Los requerimientos no funcionales se contemplan durante la implementación y la verificación. Al cerrar cada iteración se revisarán las funcionalidades integradas y los pendientes. Las demás pruebas, las correcciones y el cierre documental continuarán durante el Mes 4.
