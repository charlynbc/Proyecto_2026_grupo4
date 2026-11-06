#  

[**1. Introducción 3**](#introducción)

> [1.1. Propósito 3](#propósito)
>
> [1.2. Alcance 3](#alcance)
>
> [1.3. Definiciones, siglas y abreviaturas 3](#definiciones-siglas-y-abreviaturas)
>
> [1.4. Referencias 4](#referencias)
>
> [1.5. Visión general 4](#visión-general)

[**2. Descripción general 5**](#descripción-general)

> [2.1. Perspectiva del producto 5](#perspectiva-del-producto)
>
> [2.1.1. Interfaces de usuario 5](#interfaces-de-usuario)
>
> [2.1.2. Requisitos de hardware 5](#requisitos-de-hardware)
>
> [2.1.3. Requisitos de software 6](#requisitos-de-software)
>
> [2.1.4. Requisitos de usuario final 6](#requisitos-de-usuario-final)
>
> [2.2. Características de los usuarios 7](#características-de-los-usuarios)
>
> [2.2.1. Socio 7](#socio)
>
> [2.2.2. Funcionario 7](#funcionario)
>
> [2.2.3. Médico 7](#médico)
>
> [2.2.4. Administrador 7](#administrador)
>
> [2.3. Funcionalidades del producto 7](#funcionalidades-del-producto)

[**3. Requerimientos específicos 9**](#requerimientos-específicos)

> [3.1. Reglas generales 9](#reglas-generales)
>
> [3.1.1. Cuentas y Roles 9](#cuentas-y-roles)
>
> [3.1.2. Estados de la consulta y aviso de llegada 10](#estados-de-la-consulta-y-aviso-de-llegada)
>
> [3.1.3. Parámetros configurables 11](#parámetros-configurables)
>
> [3.1.4. Cargas masivas 12](#cargas-masivas)
>
> [3.1.5. Conflicto de interés 12](#conflicto-de-interés)
>
> [3.2. Requerimientos funcionales 14](#requerimientos-funcionales)
>
> [3.2.1. Funcionalidades comunes a todos los roles 14](#funcionalidades-comunes-a-todos-los-roles)
>
> [3.2.2. Funcionalidades del Socio 15](#funcionalidades-del-socio)
>
> [3.2.3. Funcionalidades del Funcionario 17](#funcionalidades-del-funcionario)
>
> [3.2.4. Funcionalidades del Médico 20](#funcionalidades-del-médico)
>
> [3.2.5. Funcionalidades del Administrador 22](#funcionalidades-del-administrador)
>
> [3.3. Requerimientos no funcionales 26](#requerimientos-no-funcionales)
>
> [3.3.1. Plataforma y acceso 26](#plataforma-y-acceso)
>
> [3.3.2. Seguridad 26](#seguridad)
>
> [3.3.3. Privacidad y protección de datos 27](#privacidad-y-protección-de-datos)
>
> [3.3.4. Integridad y trazabilidad 27](#integridad-y-trazabilidad)
>
> [3.3.5. Rendimiento 28](#rendimiento)
>
> [3.3.6. Disponibilidad y respaldo 28](#disponibilidad-y-respaldo)
>
> [3.3.7. Usabilidad 28](#usabilidad)
>
> [3.3.8. Notificaciones 28](#notificaciones)
>
> [3.3.9. Mantenibilidad y portabilidad 29](#mantenibilidad-y-portabilidad)

#  

# 1. Introducción

## 1.1. Propósito

Este documento reúne los requerimientos funcionales y no funcionales del sistema de agenda de consultas de una institución de asistencia médica. Describe las funciones de cada Rol, las reglas que el sistema aplica y los valores que las regulan, de modo que sirva de base para los casos de uso y el diseño.

## 1.2. Alcance

El sistema está destinado a una institución de asistencia médica. Cubre el recorrido completo de una consulta: el socio consulta la disponibilidad y agenda un número; el día de la consulta se anuncia ante un funcionario, que registra su aviso de llegada; el médico lo atiende y registra la atención en la historia clínica. También comprende la gestión de turnos, socios, personal, especialidades y consultorios.

Hay cuatro Roles: Socio, Funcionario, Médico y Administrador. El sistema se ofrece como aplicación web para los cuatro Roles y, para el Socio, también como aplicación instalable en Android, con todas las funcionalidades de su Rol. Queda fuera del alcance una versión para iOS.

También quedan fuera del alcance la integración con FONASA, el manejo de exámenes de laboratorio, el cobro de cuotas y cualquier tipo de pago. La verificación de que una persona es socio habilitado se hace fuera del sistema, antes de que el administrador cargue sus datos. El sistema tampoco aplica consecuencias a quien no asiste a una consulta agendada: solo lo registra.

## 1.3. Definiciones, siglas y abreviaturas

Los términos del negocio y los términos técnicos se definen en el Glosario del proyecto, que se entrega como documento aparte. Este documento los usa de forma consistente. Se usan además las siglas RF (requerimiento funcional), RNF (requerimiento no funcional) y CI (cédula de identidad). En este documento se utiliza Socio para el rol de la aplicación y Paciente en el contexto de la atención médica.

## 1.4. Referencias

Se toman como base la Propuesta de proyecto 2026 de la carrera, como punto de partida, y el Glosario del proyecto. El documento de casos de uso desarrolla los flujos de los requerimientos críticos.

## 1.5. Visión general

La sección 2 presenta el sistema, sus usuarios y las necesidades de hardware y software. La sección 3 reúne las reglas generales, los requerimientos funcionales y los requerimientos no funcionales.

# 2. Descripción general

## 2.1. Perspectiva del producto

El sistema reúne en un mismo circuito la disponibilidad de consultas, la agenda de los socios, el registro de aviso de llegada en la ventanilla y el registro de la atención médica. Los datos de socios y personal los carga el administrador, de a uno o desde un archivo CSV. Esa carga es el padrón del sistema: nadie accede sin figurar en él.

### 2.1.1. Interfaces de usuario

Hay dos accesos: el de socios, disponible en la aplicación web y en la aplicación Android, y el de empleados, disponible solo en la web. El Rol de cada empleado (Funcionario, Médico o Administrador) determina las funciones que ve. La aplicación Android del Socio ofrece todas las funcionalidades de su Rol y no es solo una vista adaptada de la web: aprovecha capacidades del dispositivo, como las notificaciones push.

### 2.1.2. Requisitos de hardware

Los siguientes requisitos consideran un entorno de producción para una institución de hasta 10.000 socios y aproximadamente 100 usuarios simultáneos. La capacidad deberá revisarse si aumenta la cantidad de usuarios, consultas o información almacenada.

**Servidor de aplicaciones:** Se requiere un servidor virtual con al menos 4 núcleos de procesamiento de 2,5 GHz o rendimiento equivalente, 8 GB de memoria RAM y 100 GB de almacenamiento SSD. Este servidor alojará la aplicación y los servicios necesarios para su ejecución.

**Servidor de base de datos:** Se requiere un servidor virtual independiente con al menos 4 núcleos de procesamiento de 2,5 GHz o rendimiento equivalente, 16 GB de memoria RAM y 250 GB de almacenamiento SSD. El espacio deberá poder ampliarse de acuerdo con el crecimiento de la información y del historial de consultas.

**Sistema operativo:** Ambos servidores deberán utilizar Ubuntu Server 24.04 LTS de 64 bits, o una distribución Linux equivalente con soporte vigente y compatible con los componentes del sistema.

**Conectividad:** El entorno deberá disponer de una conexión simétrica a Internet de al menos 100 Mbps, una dirección IP pública fija y los elementos de red necesarios para proteger y controlar el acceso a los servidores.

**Respaldo:** Se deberá contar con al menos 500 GB de almacenamiento separado del servidor de base de datos para conservar respaldos. La capacidad deberá ajustarse según la frecuencia de los respaldos y el tiempo durante el cual deban conservarse.

Estos valores constituyen una configuración inicial y deberán validarse mediante pruebas de carga antes de la puesta en producción.

### 2.1.3. Requisitos de software

**Servidor de aplicaciones:** El backend se ejecuta como una aplicación Spring Boot con servidor web embebido, empaquetada en una imagen de contenedor, por lo que no requiere un servidor de aplicaciones externo. Requiere el entorno de ejecución de Java 25 y una plataforma de ejecución de contenedores.

**Servidor de base de datos:** PostgreSQL 17 en un servicio gestionado.

**Servicios externos:** Un servicio de correo SMTP para el envío de correos, Firebase Cloud Messaging para las notificaciones push y un certificado TLS para la comunicación cifrada, provisto por la plataforma de despliegue.

**Plataforma de despliegue:** Una plataforma de ejecución de contenedores con dominio público y soporte de HTTPS.

### 2.1.4. Requisitos de usuario final

**Acceso web:** Computadora, tableta o teléfono con un navegador compatible (RNF-03) y conexión a internet.

**Aplicación móvil:** Dispositivo con Android 8.0 o superior (RNF-04) y conexión a internet. Para recibir notificaciones push, el usuario deberá otorgar el permiso correspondiente.

**Correo electrónico:** Cada usuario necesita una dirección de correo propia, requerida para el primer ingreso y la recuperación de contraseña.

## 2.2. Características de los usuarios

### 2.2.1. Socio

Persona que figura en el padrón como socio de la institución. Agenda y cancela sus consultas y consulta su historial desde la web o la aplicación Android. Una misma persona puede ser Socio y, a la vez, empleado de la institución: en ese caso utiliza cuentas independientes.

### 2.2.2. Funcionario

Trabaja en la ventanilla. Registra el aviso de llegada del socio, consulta las agendas y asiste en la organización de la atención. Define y administra los turnos de los médicos. El médico decide a quién llamar.

### 2.2.3. Médico

Puede tener varias especialidades. Atiende a los socios presentes en sus turnos, registra el resultado de la consulta y la atención en la historia clínica, y emite pases.

### 2.2.4. Administrador

Mantiene los datos de los que depende la operación (usuarios, especialidades y consultorios), corrige datos mal cargados y consulta listados y estadísticas.

## 2.3. Funcionalidades del producto

**Todos los Roles:** iniciar sesión (con la opción de primer ingreso), cerrar sesión, cambiar y recuperar la contraseña, editar datos personales y consultar la cartelera de novedades.

**Socio:** consultar la disponibilidad, agendar y cancelar consultas, y consultar su histórico de agendas y su historia clínica.

**Funcionario:** dar de alta y modificar turnos semanales; suspender y rehabilitar fechas de esos turnos; registrar el aviso de llegada de los socios; consultar turnos y agendas; y cancelar consultas a pedido del socio.

**Médico:** ver los turnos de una fecha y sus números, con los pacientes asignados; consultar la historia clínica previa de los pacientes con consultas agendadas con él; registrar la atención o que el paciente no se presentó a la consulta; emitir pases; consultar sus atenciones y sus pases; y cancelar consultas.

**Administrador:** publicar novedades; registrar usuarios, especialidades y consultorios, de a uno o de forma masiva; consultar listados; corregir datos; inactivar y reactivar empleados; y consultar estadísticas.

#  

# 3. Requerimientos específicos

En esta sección se describen las funciones del sistema y las condiciones que deben cumplir. Se consideran críticas las funciones necesarias para alcanzar su objetivo principal; las no críticas también forman parte del sistema. Las validaciones se incluyen en la función a la que corresponden y los valores numéricos se definen como parámetros configurables.

## 3.1. Reglas generales

Esta sección define las pautas generales, los criterios estandarizados y el marco operativo que rigen de forma transversal todos los requerimientos funcionales del sistema de agenda médica. En ella se establecen los principios conceptuales y las restricciones que aseguran la consistencia en el tratamiento de cuentas, perfiles, estados de atención, parámetros configurables y políticas de seguridad y transparencia, garantizando un comportamiento uniforme e integrado en todos los módulos de la plataforma.

### 3.1.1. Cuentas y Roles

Los Roles son Socio, Funcionario, Médico y Administrador. Los tres últimos son empleados.

Una persona, identificada por su CI, puede tener una sola cuenta de Socio y una sola cuenta de empleado habilitada, cada una con su contraseña, correo, teléfonos, dirección y estado. El Rol de una cuenta no se modifica. Para cambiar el Rol de empleado, el administrador inactiva la cuenta anterior y registra otra con el nuevo Rol, conservando el historial de la anterior. Las cuentas de empleado inactivadas se conservan, pero no pueden quedar dos habilitadas simultáneamente para la misma CI.

CI, nombre, apellido y fecha de nacimiento son únicos por persona y comunes a todas sus cuentas y solo los corrige el Administrador.

Una cuenta inactiva no puede iniciar sesión ni seguir operando mediante una sesión que ya tenía abierta. El primer ingreso no puede revertir una inactivación administrativa.

### 3.1.2. Estados de la consulta y aviso de llegada

En esta subsección se definen los estados de las consultas, las situaciones que se calculan a partir de ellas y el alcance del aviso de llegada.

Cada número agendado da lugar a una consulta. Los estados que el sistema guarda son:

**Estados registrados:**

**Agendada:** el número está asignado al socio.

**Atendida:** el médico registró la atención.

**Cancelada por el socio:** la canceló el socio o, a pedido suyo, un funcionario.

**Cancelada por la institución:** la canceló un médico o una suspensión de la fecha del turno.

**No se presentó a la consulta:** el médico indicó que un socio con aviso de llegada registrado ese día no se presentó a su consulta. El registro es definitivo, sin rectificación ni reapertura. Se conserva el aviso de llegada para las demás consultas de ese día.

Dos estados no se guardan: se calculan al consultar. Una consulta que sigue Agendada al terminar el día se considera No asistió si el socio no registró su llegada ese día, y No atendida si la registró. No atendida indica que no se guardó una atención ni se registró No se presentó a la consulta; no identifica la causa. Estos estados aparecen en el histórico de agendas y en las estadísticas.

El aviso de llegada lo registra un funcionario sobre un socio y un día (RF-16) y vale hasta el fin de ese día. No es un estado de la consulta. Los días terminan a las 24:00, hora oficial de Uruguay.

### 3.1.3. Parámetros configurables

Esta subsección establece y detalla el conjunto de parámetros configurables que regulan las reglas de negocio, límites de agenda, políticas de cancelación, duraciones de consulta, tiempos de vigencia y criterios de seguridad del sistema. Estos valores son configuración del sistema y deberán poder modificarse sin cambiar el código fuente. No se incluye una pantalla de administración para gestionarlos.

**Parámetros:**

**Anticipación máxima para agendar:** 30 días.

**Anticipación mínima para agendar:** 2 horas antes de la hora del número.

**Anticipación mínima para cancelar:** 2 horas antes del inicio de la consulta.

**Consultas activas por especialidad:** 1.

**Consultas activas en total:** 3.

**Duración de un número:** de 10 a 60 minutos, en pasos de 5.

**Vigencia inicial de un pase:** 90 días.

**Vigencia que el médico puede fijar:** de 1 a 365 días.

**Vigencia de los enlaces enviados por correo:** 24 horas y un solo uso.

**Antelación del recordatorio de consulta:** 24 horas.

**Longitud mínima de la contraseña:** 8 caracteres.

Una consulta activa es una consulta Agendada cuyo día todavía no terminó.

### 3.1.4. Cargas masivas

Esta subsección define los criterios técnicos, reglas de validación y procedimientos estandarizados que rigen el procesamiento masivo de datos mediante archivos externos en formato CSV. En ella se detallan las exigencias de formato, el tratamiento de errores fila por fila, las políticas de previsualización antes de la incorporación definitiva y las reglas para el manejo de duplicados, garantizando la integridad de la base de datos durante altas masivas de usuarios, especialidades y consultorios.

El archivo es un CSV con codificación UTF-8 y encabezados. El separador puede ser coma o punto y coma. Las columnas son los campos del alta individual correspondiente.

Antes de importar, el sistema muestra una previsualización con la cantidad de filas, las válidas y las que tienen error, con el motivo de cada una.

Se importan las filas válidas. Las inválidas se rechazan y el administrador puede descargar el detalle con su motivo, corregirlas y volver a cargarlas.

Una fila repetida dentro del archivo, o que ya existe en el sistema, se rechaza; los registros existentes no se actualizan. Dentro del archivo se conserva la primera aparición.

### 3.1.5. Conflicto de interés

Esta subsección establece las políticas de ética operativa y las restricciones de acceso diseñadas para prevenir conflictos de interés en aquellos usuarios que poseen simultáneamente un rol de empleado (Funcionario o Médico) y una cuenta activa de Socio. En ella se definen las limitaciones explícitas para impedir que un usuario realice acciones sobre su propia atención médica o sobre sus gestiones administrativas personales, asegurando que dichas operaciones sean siempre auditadas o ejecutadas por otro funcionario autorizado.

Un empleado que también es Socio no puede realizar, con su cuenta de empleado, acciones sobre su propia cuenta de Socio. Un Funcionario no registra su propio aviso de llegada ni cancela sus propias consultas. Un Médico no registra el resultado de una consulta en la que él mismo es el socio ni cancela sus propias consultas. Esas acciones las realiza otro empleado.

##  

## 3.2. Requerimientos funcionales

En esta sección se presentan en detalle cada una de las funcionalidades que conforman la lógica de negocio del sistema, agrupadas formalmente según el rol operativo que las ejecuta de forma principal: funciones transversales comunes a todos los perfiles, y módulos específicos para Socios, Funcionarios, Médicos y Administradores. Cada requerimiento establece de manera rigurosa las condiciones de entrada, las reglas de validación y los flujos de respuesta necesarios para asegurar un control operativo integral, manteniendo la trazabilidad y la consistencia de la información en todo el circuito asistencial.

Adicionalmente, se especifica de forma explícita el nivel de criticidad asignado a cada requerimiento (distinguiendo entre funcionales críticos y no críticos) con el propósito de priorizar las etapas clave del desarrollo, optimizar la gestión de pruebas y garantizar la máxima disponibilidad en los procesos operativos de alto impacto para la institución. En conjunto, la sección comprende un total de 45 requerimientos funcionales (22 de carácter crítico y 23 no críticos), estructurando de punta a punta la interacción de los usuarios con la plataforma.

### 3.2.1. Funcionalidades comunes a todos los roles

**RF-01 \[Crítico\] Inicio de sesión:** Permitir que un usuario con cuenta activa ingrese con su CI y su contraseña y acceda únicamente a las funciones de su Rol. Hay un acceso para socios (web y aplicación Android) y otro para empleados (solo web). Cada cuenta ingresa por el acceso que le corresponde. Si los datos no son correctos, el mensaje de error no indica cuál de los dos falló. El empleado entra a la interfaz que corresponde a su Rol.

**RF-02 \[Crítico\] Primer ingreso:** Permitir que una persona cargada en el padrón active su cuenta la primera vez que entra, desde el acceso de socios o desde el de empleados, según corresponda. El socio o empleado puede solicitar la activación de su cuenta con su CI. El sistema identifica la cuenta según el acceso utilizado: Socio o empleado. El sistema responde siempre lo mismo, exista o no la CI: que, si está registrada, se le envió un correo. Si existe una cuenta para esa CI en el acceso utilizado que todavía no se activó y no fue inactivada por el administrador, el correo llega al correo cargado en el padrón e incluye un enlace de un solo uso, válido por 24 horas. Si no existe esa cuenta, no se envía un correo. Si la cuenta ya está activa, el correo indica cómo recuperar la contraseña (RF-05). Para activar la cuenta, la persona debe proporcionar su dirección, al menos un teléfono y una contraseña. El correo registrado no puede modificarse durante el primer ingreso. La cuenta queda activa al completar el primer ingreso, siempre que no haya sido inactivada por el administrador. El sistema verifica esa condición al solicitar y al completar la activación; un enlace de primer ingreso no revierte una inactivación administrativa. Si el enlace venció o ya se usó, la persona debe solicitar otro. El mecanismo es el mismo para socios y empleados: el administrador no envía ni reenvía nada.

**RF-03 \[No crítico\] Cierre de sesión:** Permitir que el usuario finalice su sesión.

**RF-04 \[No crítico\] Cambio de contraseña:** Permitir que un usuario autenticado cambie su contraseña, ingresando la actual. La nueva debe cumplir la longitud mínima.

**RF-05 \[No crítico\] Recuperación de contraseña:** Permitir que una persona con cuenta recupere el acceso ingresando su CI en el acceso correspondiente a su cuenta (Socio o empleado). El sistema envía al correo de la cuenta un enlace de un solo uso, válido por 24 horas, para definir una nueva contraseña. La respuesta es la misma exista o no la cuenta. Si no existe una cuenta para esa CI en ese acceso, no se envía un correo. Si la CI figura en el padrón pero todavía no activó su cuenta, el correo indica que debe usar “Es mi primera vez”.

**RF-06 \[No crítico\] Edición de datos personales:** Permitir que cada usuario actualice sus teléfonos, su dirección y su correo. El cambio de correo se aplica cuando el usuario lo confirma desde un enlace enviado al correo nuevo. CI, nombre, apellido, fecha de nacimiento y especialidades solo los corrige el Administrador (RF-38). El Rol de la cuenta no se modifica.

**RF-07 \[No crítico\] Consulta de la cartelera de novedades:** Permitir que todos los usuarios consulten los anuncios publicados por la institución, del más reciente al más antiguo.

### 3.2.2. Funcionalidades del Socio

**RF-08 \[Crítico\] Consulta de disponibilidad:** Permitir que el socio consulte los números libres por especialidad y médico antes de agendar. **Filtros:** especialidad y médico (ambos opcionales por separado, pero se debe indicar al menos uno) y rango de fechas. Si se busca por médico únicamente, se muestran números de todas sus especialidades. Si ambos filtros son válidos pero el médico no atiende la especialidad, se muestra una lista vacía. Orden: fecha y hora más próximas (por defecto) y apellido del médico. Cada resultado muestra fecha, hora de inicio y de fin, médico, especialidad y consultorio, e indica si la especialidad requiere pase. Solo se ofrecen los números que todavía pueden agendarse según la anticipación máxima y la mínima. No se ofrecen los números de fechas suspendidas del turno, incluidas las suspendidas por el médico. La anticipación mínima se calcula desde la hora de inicio del número, que es la hora estimada de atención.

**RF-09 \[Crítico\] Agenda de consulta:** Permitir que el socio agende una consulta eligiendo un número libre, identificado dentro del turno como 1, 2, 3, etc. Al confirmar, la consulta queda Agendada, con un identificador único, y el socio ve el número asignado, el médico, la fecha, la hora y el consultorio. El número identifica la franja reservada y sirve para organizar el turno, pero no establece una fila obligatoria de atención. El médico decide a quién llamar según su criterio, con los pacientes y sus avisos de llegada a la vista, aunque el paciente tenga un número posterior. Antes de confirmar, el sistema verifica: Anticipación: la fecha está a no más de 30 días y la hora del número a no menos de 2 horas. Límites: el socio no tiene otra consulta activa en esa especialidad y tiene menos de 3 consultas activas en total. Disponibilidad: el número sigue libre. Si otro socio lo agendó antes, se avisa y el socio elige otro. Superposición: la consulta no se solapa en el tiempo con otra consulta agendada del mismo socio. Pase: una especialidad libre no exige nada. Si la especialidad requiere pase, el sistema verifica que el socio tenga un pase a esa especialidad sin usar y con un vencimiento que no sea anterior a la fecha de la consulta. El pase se consume al confirmar la agenda y se conserva la identificación del utilizado para esa consulta. Su disponibilidad se determina por su uso y su vencimiento. Solo una cancelación devuelve el pase utilizado: vuelve a estar disponible si conserva su vigencia original, sin cambiar el vencimiento. No asistió, No atendida y No se presentó a la consulta no lo devuelven.

**RF-10 \[No crítico\] Cancelación de consulta por el socio:** Permitir que el socio cancele una consulta propia que esté Agendada. El socio puede cancelarla hasta 2 horas antes de la hora del número y solo si no está presente ese día. La consulta pasa a Cancelada por el socio y se conserva en el histórico. El pase utilizado se devuelve según RF-09. El número vuelve a ofrecerse si todavía cumple la anticipación mínima. Si el socio no cancela la consulta ni registra su aviso de llegada, la consulta queda como No asistió al cerrar el día.

**RF-11 \[Crítico\] Histórico de agendas:** Permitir que el socio consulte, busque y filtre sus consultas, con el detalle de cada una. Cada consulta muestra identificador, especialidad, médico, fecha, hora, consultorio y estado. Incluye No se presentó a la consulta. Además de los estados que se guardan, muestra No asistió y No atendida. **Filtros:** estado, rango de fechas, especialidad y médico. Orden: fecha (la más reciente primero, por defecto) y especialidad.

**RF-12 \[Crítico\] Consulta de historia clínica:** Permitir que el socio consulte sus atenciones registradas y acceda al detalle de cada una. **Filtros:** rango de fechas, especialidad, médico y búsqueda opcional por texto en el tratamiento. Los filtros pueden combinarse. Orden: fecha y especialidad. El detalle muestra todo lo que el médico registró (afección, tratamiento y observaciones), junto con fecha, médico y especialidad, y los pases que emitió, con su vigencia.

### 3.2.3. Funcionalidades del Funcionario

**RF-13 \[Crítico\] Alta de turno semanal:** Permitir que el funcionario dé de alta una configuración semanal de turnos para un médico, una especialidad y un consultorio. Define un día de la semana y las fechas de inicio y finalización; se genera un turno concreto para cada fecha de ese día comprendida en el período. Cada turno concreto tiene un identificador único autogenerado y ofrece sus números, identificados como 1, 2, 3, etc., únicos dentro de ese turno. Puede suspenderse o rehabilitarse sin afectar los turnos de las demás fechas. **Datos:** médico activo, especialidad (una de las del médico), día de la semana, consultorio, fecha de inicio, fecha de finalización y los números, cada uno con su hora de inicio y de fin. **Condiciones:** las fechas de inicio y finalización son obligatorias; la de finalización debe ser posterior o igual a la fecha de inicio. Cada número debe durar entre 10 y 60 minutos, con inicio y fin en múltiplos de 5 minutos, y puede haber huecos entre ellos. Los números no pueden solaparse entre sí. En las fechas del período de vigencia que queden activas, tampoco pueden solaparse con números de turnos activos del mismo médico o del mismo consultorio. **Cupo:** corresponde a la cantidad de números y no puede ser menor que uno.

**RF-14 \[Crítico\] Suspensión de fechas de turnos:** Permitir que el funcionario suspenda uno o varios turnos concretos de fechas actuales o futuras, identificados por médico, especialidad y rango de fechas. Puede suspender algunos o todos los turnos activos del rango seleccionado. La operación requiere confirmación, informando las fechas afectadas y la cantidad de consultas que se cancelarán, y admite una observación opcional. La suspensión es inmediata: los turnos seleccionados dejan de ofrecer números y sus consultas Agendadas pasan a Cancelada por la institución. Las demás consultas conservan su estado y todas permanecen en el historial. Se devuelven los pases utilizados según RF-09 y se notifica de inmediato a cada socio afectado, incluyendo la observación si se ingresó (RNF-24). Esta puede informar que se creará otro turno para que el socio vuelva a agendarse. Las reservas canceladas no se recuperan al rehabilitar. No hay fecha futura de efecto ni rehabilitación automática; la configuración semanal y los turnos no seleccionados se conservan.

**RF-15 \[Crítico\] Rehabilitación de fechas de turnos:** Permitir que el funcionario vuelva a habilitar uno o varios turnos concretos suspendidos de fechas actuales o futuras, identificados por médico, especialidad y rango de fechas. Puede rehabilitar algunos o todos los turnos suspendidos del rango seleccionado. El médico debe estar activo. Se conserva el médico, la especialidad, la fecha, el consultorio y los números con sus horarios; la rehabilitación no permite modificarlos. Se verifica que los números no se solapen con otros turnos activos del mismo médico o del mismo consultorio en esas fechas y horarios. Los turnos rehabilitados vuelven a ofrecer sus números según las condiciones de agenda. Las consultas canceladas por la suspensión no se restauran: los socios deben agendar una nueva consulta.

**RF-16 \[Crítico\] Registro de aviso de llegada:** Permitir que el funcionario registre que un socio se presentó en la ventanilla el día de sus consultas. Busca al socio por CI y el sistema muestra sus consultas Agendadas de ese día, con médico, hora y consultorio. Solo se puede registrar el aviso de llegada si tiene al menos una consulta Agendada para ese día. El aviso de llegada se registra una sola vez y vale hasta el fin del día para todas las consultas del socio. No hay ventana de antelación: el socio puede llegar cuando quiera. Si se intenta registrar el aviso nuevamente, el sistema conserva el registro original. El sistema guarda quién registró el aviso de llegada y a qué hora llegó el socio. Los socios que registraron su llegada se ven en tiempo real en la consulta de agendas (RF-18) y en los pacientes de un turno (RF-21). El médico decide a quién llamar con los pacientes y sus avisos de llegada a la vista; el sistema no impone un orden de atención. Aplica el conflicto de interés de la sección 3.1.5.

**RF-17 \[Crítico\] Consulta de turnos:** Permitir que el funcionario busque y consulte las fechas concretas de los turnos semanales. Cada resultado muestra fecha, médico, especialidad, día de la semana, horario, consultorio, cantidad de números y estado de esa fecha (activa o suspendida). También permite consultar la configuración semanal y sus fechas de inicio y finalización. **Filtros:** médico, especialidad, día de la semana, rango de fechas y estado de la fecha. Orden: fecha y horario, médico y especialidad.

**RF-18 \[Crítico\] Consulta de agendas:** Permitir que el funcionario busque y consulte las consultas agendadas, con el fin de realizar el seguimiento en ventanilla y asistir al socio. Para cada consulta se detallará: identificador, socio, médico, especialidad, fecha, hora, consultorio, estado y la confirmación de llegada junto con su hora correspondiente. **Filtros:** CI del socio, identificador, fecha, médico, estado y aviso de llegada. Orden: fecha y hora de la consulta y hora de llegada. Filtrando por la fecha de hoy y por avisos de llegada se obtiene la lista de socios presentes en tiempo real.

**RF-19 \[No crítico\] Cancelación de consulta por el funcionario:** Permitir que el funcionario cancele una consulta Agendada, a pedido del socio. Puede hacerlo hasta 2 horas antes del inicio de la consulta. El funcionario decide si corresponde. La consulta pasa a Cancelada por el socio, se guarda qué funcionario la canceló y el sistema envía al socio una notificación sobre la cancelación (RNF-24). El pase utilizado se devuelve según RF-09. El número vuelve a ofrecerse si todavía cumple la anticipación mínima. Aplica el conflicto de interés de la sección 3.1.5.

**RF-20 \[No crítico\] Modificación de turno semanal:** Permitir que el funcionario modifique el consultorio de una configuración semanal de turnos, con turnos activos o suspendidos, siempre que no tenga consultas Agendadas cuyo día todavía no terminó. La configuración resultante debe cumplir las validaciones del alta (RF-13), incluido el control de solapamientos durante su vigencia. El médico, la especialidad, el día de la semana y los horarios de los números no se modifican: para cambiarlos se da de alta otro turno. La modificación afecta únicamente las fechas actuales y futuras, conserva los turnos suspendidos y no altera las consultas ni la configuración de fechas anteriores. Si existen consultas Agendadas que impiden modificarlo, el funcionario puede suspender los turnos correspondientes y cancelar esas reservas mediante RF-14, y dar de alta otro turno. Las reservas no se trasladan automáticamente; la observación de la suspensión permite avisar que podrán agendarse nuevamente.

### 3.2.4. Funcionalidades del Médico

**RF-21 \[Crítico\] Turnos y pacientes de una fecha:** Permitir que el médico seleccione una fecha y consulte sus turnos de ese día. Al elegir un turno, ve todos sus números, con hora de inicio y de fin. Para cada número reservado se muestran nombre, apellido y CI del paciente, estado de la consulta y aviso de llegada con su hora. Los números sin paciente asignado se muestran como Sin reserva y se indican como disponibles solo si todavía pueden agendarse. Filtro por aviso de llegada. Orden: hora del número y hora de llegada. La lista se actualiza en tiempo real. El médico atiende a los pacientes que llegaron en el orden que resuelve él mismo.

**RF-22 \[No crítico\] Consulta de historia clínica previa:** Permitir que el médico consulte la historia clínica completa de un paciente, sin modificarla, mientras tenga una consulta Agendada con él cuyo día todavía no terminó. El acceso puede realizarse antes de la fecha de la consulta y no requiere aviso de llegada. Fuera de esa condición el sistema no muestra la historia clínica completa. La consulta posterior de las atenciones propias se mantiene según RF-25.

**RF-23 \[Crítico\] Registro del resultado de la consulta:** Permitir que el médico registre la atención de un paciente que tiene una consulta Agendada con él y cuyo socio registró su llegada ese día. La consulta debe corresponder a ese día. Campos de la atención: afección (obligatorio), tratamiento y observaciones (opcionales). No hay borradores: la atención se guarda al finalizar y la consulta pasa a Atendida; el sistema envía al socio una notificación sobre la actualización de su historia clínica (RNF-24). Como alternativa, si el socio registró su llegada pero no se presentó a la consulta, el médico puede seleccionar No se presentó a la consulta y confirmar. En ese caso se guarda ese estado, quién lo registró y cuándo, sin registrar una atención ni exigir campos clínicos. El registro es definitivo y no admite rectificación ni reapertura. El aviso de llegada permanece válido para las demás consultas del socio ese día. Este estado no libera el número ni devuelve el pase utilizado. Si no se guarda ninguna de las dos opciones, la consulta sigue Agendada y, al terminar el día, figura como No atendida. El pase ya se consumió al agendar (RF-09). Aplica el conflicto de interés de la sección 3.1.5.

**RF-24 \[Crítico\] Registro de pases:** Permitir que el médico, durante el registro de una atención, emita uno o más pases para el paciente a distintas especialidades, incluida la especialidad en la que lo está atendiendo. Todos se registran y presentan como pases, con el mismo funcionamiento, cualquiera sea el médico emisor o la especialidad de destino. Se guardan junto con la atención y no pueden emitirse posteriormente desde una atención ya guardada. Cada pase identifica al paciente, al médico emisor, la especialidad de destino, la fecha de emisión y el vencimiento. Autoriza una consulta en la especialidad de destino, sin exigir que sea con el médico que lo emitió, y solo tiene efecto cuando esa especialidad requiere pase. El médico fija hasta qué fecha vale; por defecto son 90 días y puede ajustarse entre 1 y 365 días. El pase es de uso único y se consume al agendar (RF-09). No puede emitirse otro pase si el socio ya tiene uno disponible y vigente para esa especialidad, ni si tiene una consulta Agendada en ella cuyo día todavía no terminó. La atención que se está registrando como Atendida deja de estar Agendada y no impide emitir el pase para la siguiente consulta.

**RF-25 \[No crítico\] Consultas atendidas por el médico:** Permitir que el médico busque y consulte las atenciones que registró. **Filtros:** rango de fechas, paciente (CI o apellido) y especialidad. Orden: fecha (la más reciente) y apellido del paciente.

**RF-26 \[No crítico\] Pases emitidos:** Permitir que el médico consulte los pases que emitió. Cada uno muestra paciente, especialidad de destino, fecha de emisión, vencimiento y su situación: disponible (sin utilizar y vigente), utilizado para agendar o vencido sin utilizar. La situación se obtiene de su uso y su vencimiento; no se mantiene un estado intermedio. Si se cancela la consulta, la devolución se refleja según RF-09. Filtro: situación. Orden: vencimiento y fecha de emisión.

**RF-27 \[No crítico\] Cancelación por el médico:** Permitir que el médico cancele una consulta Agendada suya, o suspenda todas las consultas Agendadas de uno de sus turnos en una fecha, indicando un motivo. Puede hacerlo hasta 2 horas antes de la hora del número de cada consulta afectada. Este límite corresponde a la cancelación por el médico; la suspensión institucional realizada por el funcionario mediante RF-14 es inmediata. Los imprevistos posteriores se coordinan con la administración usando esa suspensión cuando corresponda, sin un circuito especial en el sistema. Las consultas pasan a Cancelada por la institución y el sistema envía de inmediato una notificación sobre la cancelación a cada socio afectado, incluyendo el motivo (RNF-24). Los pases utilizados se devuelven según RF-09. Al cancelar todo el turno de una fecha, esa fecha queda suspendida de inmediato y deja de ofrecer números, con el mismo efecto de RF-14 y sin afectar las demás fechas. Rehabilitarla no restaura las consultas canceladas. Al cancelar una sola consulta, su número vuelve a ofrecerse si todavía cumple la anticipación mínima. Aplica el conflicto de interés de la sección 3.1.5.

### 3.2.5. Funcionalidades del Administrador

**RF-28 \[No crítico\] Publicación de novedades:** Permitir que el administrador publique anuncios, con texto, imágenes o ambos, en la cartelera de novedades.

**RF-29 \[Crítico\] Alta individual de especialidades:** Permitir que el administrador registre una especialidad con su nombre, único sin distinguir mayúsculas, e indique si requiere pase para agendar. Solo el Administrador cambia luego esa exigencia (RF-38). El cambio rige para las consultas que se agenden desde ese momento y no afecta a las ya agendadas.

**RF-30 \[No crítico\] Carga masiva de especialidades:** Permitir que el administrador incorpore especialidades desde un archivo CSV, con las columnas nombre y requiere_pase (sí o no), según las reglas de la sección 3.1.4.

**RF-31 \[Crítico\] Alta individual de usuarios:** Permitir que el administrador registre en el padrón a una persona con su Rol (Socio, Médico, Funcionario o Administrador), para que luego active su cuenta (RF-02). Al registrarla, el sistema no envía ningún correo. **Datos:** CI (con dígito verificador válido), nombre, apellido, fecha de nacimiento, correo, teléfono 1 (obligatorio), teléfono 2, dirección (opcional) y Rol. Si el Rol es Médico, también una o más especialidades existentes; para los demás Roles, no corresponden. Una CI puede tener una sola cuenta de Socio y una sola cuenta de empleado habilitada. Se rechaza el alta de una segunda cuenta de Socio. Para registrar una cuenta con otro Rol de empleado, la anterior debe haber sido inactivada por el administrador; se conserva su historial y no pueden quedar ambas habilitadas simultáneamente. Una cuenta de empleado pendiente de primer ingreso también impide registrar otra para la misma CI, salvo que haya sido inactivada administrativamente. Si la CI ya existe, el nombre, el apellido y la fecha de nacimiento deben coincidir con los ya registrados. Si no coinciden, se rechaza con ese motivo y el administrador corrige primero el dato (RF-38). El correo puede repetirse entre personas. El primer administrador se incorpora con una carga inicial, fuera de la aplicación.

**RF-32 \[No crítico\] Carga masiva de usuarios:** Permitir que el administrador incorpore usuarios desde un archivo CSV, con las reglas de la sección 3.1.4 y las de RF-31. Columnas: ci, nombre, apellido, fecha_nacimiento, correo, telefono_1, telefono_2, direccion, rol y especialidades. Son obligatorias ci, nombre, apellido, fecha_nacimiento, correo, telefono_1 y rol. La columna especialidades es obligatoria solo si el rol es Médico. Las especialidades de un médico se separan con “\|”. Cada fila es una cuenta: una persona con dos cuentas aparece en dos filas, con distinto rol. Las especialidades deben existir antes de la carga. Una fila con una especialidad desconocida se rechaza.

**RF-33 \[Crítico\] Alta individual de consultorios:** Permitir que el administrador registre consultorios, con un nombre o número único y su ubicación (piso o sector), que luego se asignan a los turnos y a las consultas.

**RF-34 \[No crítico\] Carga masiva de consultorios:** Permitir que el administrador incorpore consultorios desde un archivo CSV, con las columnas nombre y ubicacion, según las reglas de la sección 3.1.4.

**RF-35 \[Crítico\] Consulta de usuarios:** Permitir que el administrador busque y consulte las cuentas del padrón, una fila por cuenta. Cada fila muestra CI, nombre, apellido, Rol, correo, estado y si la cuenta ya se activó. Una persona con varias cuentas, incluidas las cuentas de empleado anteriores inactivadas, aparece una vez por cada cuenta. **Filtros:** Rol, estado y texto (CI o apellido). Orden: apellido y fecha de alta.

**RF-36 \[No crítico\] Consulta de especialidades:** Permitir que el administrador busque y consulte las especialidades registradas. Cada una muestra su nombre y si requiere pase. Filtros: nombre y requiere pase. Orden: nombre y fecha de alta.

**RF-37 \[No crítico\] Consulta de consultorios:** Permitir que el administrador busque y consulte los consultorios registrados. Cada uno muestra su nombre y su ubicación. Filtros: nombre o número y ubicación. Orden: nombre y ubicación.

**RF-38 \[No crítico\] Corrección de datos administrados:** Permitir que el administrador corrija datos ya registrados. Puede corregir CI, nombre, apellido, fecha de nacimiento, correo, teléfonos, dirección y especialidades de un usuario; nombre y exigencia de pase de una especialidad; nombre y ubicación de un consultorio. No cambia el Rol de una cuenta. CI, nombre, apellido y fecha de nacimiento son únicos por persona: la corrección vale para todas sus cuentas. No se quita a un médico una especialidad en la que tiene turnos activos o consultas futuras. Las consultas y las historias clínicas ya registradas conservan su estado y su contenido.

**RF-39 \[Crítico\] Estadísticas por especialidad:** Permitir que el administrador consulte la demanda de cada especialidad: la cantidad de consultas agendadas en el período, contadas por la fecha en que se agendaron e incluidas las que luego se cancelaron.

**RF-40 \[Crítico\] Estadísticas por turno:** Permitir que el administrador consulte la utilización de cada turno: el porcentaje de números ocupados sobre los números ofrecidos en las fechas del período en que la fecha del turno estuvo activa. Un número está ocupado si su consulta está Agendada, Atendida, No asistió, No atendida o No se presentó a la consulta; las canceladas lo dejan libre.

**RF-41 \[Crítico\] Estadísticas de consultas:** Permitir que el administrador consulte la cantidad de consultas del período, según la fecha de la consulta, por estado (Agendada, Atendida, Cancelada por el socio, Cancelada por la institución, No asistió, No atendida y No se presentó a la consulta) y la tasa de cancelación por el socio: las canceladas por el socio sobre el total. Si el total es cero, se muestra Sin datos; si hay consultas y ninguna fue cancelada por el socio, se muestra 0 %.

**RF-42 \[No crítico\] Estadísticas de inasistencia:** Permitir que el administrador consulte en qué especialidades y con qué médicos se concentran las inasistencias. Se calcula el porcentaje de consultas No asistió o No se presentó a la consulta sobre las consultas del período cuyo día ya terminó y que no fueron canceladas. El administrador elige agrupar por especialidad o por médico. Cada fila muestra por separado las cantidades de Atendida, No asistió, No se presentó a la consulta y No atendida, y el porcentaje de inasistencia. No atendida no se cuenta como inasistencia. El orden por defecto es de mayor a menor porcentaje. Se cuentan las consultas según su fecha.

**RF-43 \[No crítico\] Estadísticas de pases:** Permitir que el administrador consulte cuántos pases se emitieron en el período, según su fecha de emisión, y qué pasó con ellos, agrupados por la especialidad de destino. Cada fila muestra la cantidad de pases emitidos y cuántos están utilizados para agendar, disponibles (sin utilizar y vigentes) y vencidos sin utilizar. La cancelación devuelve el pase según RF-09 y su situación se actualiza en consecuencia. El porcentaje de utilizados se calcula sobre los ya resueltos, es decir, los utilizados más los vencidos sin utilizar. Se puede filtrar por la especialidad en la que se emitió el pase, por ejemplo Medicina General.

**RF-44 \[No crítico\] Estadísticas de días y franjas pico:** Permitir que el administrador consulte en qué días de la semana y en qué franjas horarias se concentra la actividad, en una tabla de día de la semana por franja de una hora, con la cantidad en cada celda. Hay dos vistas. En la vista de consultas, cada consulta se ubica en la franja en que empieza su hora y se cuentan las Agendada, Atendida, No asistió, No atendida y No se presentó a la consulta; las canceladas no se cuentan. En la vista Consultas con llegada, se cuentan las consultas a las que aplica el aviso de llegada del socio de ese día (RF-16), según la hora del aviso. Un único aviso puede corresponder a varias consultas: si el socio tiene dos consultas ese día, ambas cuentan como consultas con llegada. El filtro por especialidad se aplica a la especialidad de cada consulta. Las estadísticas RF-39 a RF-44 usan un rango de fechas a elección, con el mes en curso por defecto. En cualquier porcentaje de RF-39 a RF-44, un denominador cero se muestra como Sin datos; con denominador positivo y numerador cero, se muestra 0 %.

**RF-45 \[No crítico\] Inactivación y reactivación de empleados:** Permitir que el administrador inactive la cuenta de un empleado, conservando su historial, y la reactive más adelante. Una cuenta inactiva no puede iniciar sesión ni seguir operando con una sesión abierta. No puede reactivarse si existe otra cuenta de empleado habilitada o pendiente de primer ingreso para la misma CI que no haya sido inactivada administrativamente. Quedan registrados quién la inactivó o reactivó y cuándo. Un médico solo puede inactivarse si no tiene fechas activas de turnos cuyo día todavía no terminó ni consultas Agendadas cuyo día todavía no terminó. Antes hay que suspender todas las fechas actuales y futuras de sus turnos mediante RF-14, seleccionándolas en un rango de fechas que cubra la vigencia restante; sus consultas Agendadas se cancelan. Al reactivar a un médico, esas fechas siguen suspendidas hasta que se rehabiliten (RF-15). La cuenta de Socio de la misma persona no se ve afectada.

## 3.3. Requerimientos no funcionales

Los requerimientos no funcionales establecen las condiciones de calidad, seguridad, operación y entorno que el sistema debe cumplir, con independencia de cada funcionalidad. Los valores indicados corresponden al alcance de un prototipo y podrán ajustarse según los resultados de la etapa de verificación.

### 3.3.1. Plataforma y acceso

**RNF-01 Plataformas:** El sistema deberá ofrecer una aplicación web para los cuatro Roles y una aplicación instalable en Android para el Socio, con todas las funcionalidades de su Rol. La aplicación móvil no será solo una vista adaptada de la web.

**RNF-02 Accesos diferenciados:** Habrá un acceso para socios, disponible en la web y en la aplicación Android, y otro para empleados, disponible solo en la web.

**RNF-03 Compatibilidad de navegadores:** La aplicación web deberá funcionar en las dos últimas versiones estables de Google Chrome, Microsoft Edge, Mozilla Firefox y Safari, en computadoras y en dispositivos móviles.

**RNF-04 Compatibilidad móvil:** La aplicación Android deberá funcionar en dispositivos con Android 8.0 (nivel de API 26) o superior.

### 3.3.2. Seguridad

**RNF-05 Control de acceso por Rol:** Cada usuario deberá acceder solo a las funciones y a la información de su Rol. Un socio ve únicamente sus propias consultas y su propia historia clínica. El médico accede a la historia clínica de un socio solo en las condiciones de RF-22. El control se aplicará en el servidor en cada operación, y no solo en la interfaz. Una cuenta inactiva no podrá realizar operaciones aunque conserve una sesión abierta.

**RNF-06 Almacenamiento de contraseñas:** Las contraseñas no deberán almacenarse en texto plano ni en un formato reversible. Se guardará únicamente su resumen, obtenido con una función de hash adaptativa y con sal.

**RNF-07 Comunicación cifrada:** Toda comunicación entre las aplicaciones y el servidor deberá realizarse sobre HTTPS. El tráfico sin cifrar se redirigirá al protocolo seguro.

**RNF-08 Gestión de sesiones:** Las credenciales de sesión deberán tener un vencimiento acotado y poder renovarse sin que el usuario vuelva a ingresar su contraseña. Al cerrar sesión, deberán invalidarse en el servidor para que no puedan reutilizarse.

**RNF-09 Protección de credenciales del sistema:** Las contraseñas de la base de datos, las claves de firma y las credenciales de servicios externos no deberán incluirse en el código fuente ni en el repositorio. Se proveerán al sistema mediante variables de entorno.

**RNF-10 Mensajes de error seguros:** Los mensajes de error no deberán revelar información interna del sistema ni confirmar la existencia de una cuenta, según lo definido en RF-01, RF-02 y RF-05.

### 3.3.3. Privacidad y protección de datos

**RNF-11 Tratamiento de datos sensibles:** El sistema trata datos de salud, que la Ley N.º 18.331 de Protección de Datos Personales clasifica como datos sensibles. Su tratamiento deberá limitarse a la finalidad de la atención, y el acceso deberá restringirse a quienes lo requieran para esa finalidad.

**RNF-12 Datos en registros técnicos:** Los registros técnicos del sistema no deberán contener contraseñas, credenciales de sesión ni el contenido de las historias clínicas.

### 3.3.4. Integridad y trazabilidad

**RNF-13 Unicidad de asignación:** Cada turno concreto de una fecha tiene un identificador único y cada número es único dentro de ese turno. Para una misma combinación de identificador de turno y número solo podrá existir una consulta no cancelada, incluso cuando dos socios intenten agendarla al mismo tiempo. Una reserva cancelada se conserva en el historial y no impide volver a asignar el número. Esta condición deberá garantizarse en la base de datos y no solo en la aplicación.

**RNF-14 Conservación del historial:** Las consultas, incluidas las canceladas, y las atenciones registradas deberán conservarse para su consulta posterior. Ninguna consulta se elimina. Esta conservación no implica mantener versiones anteriores de los datos corregidos ni un historial general de modificaciones.

**RNF-15 Zona horaria:** Los días, los horarios y los vencimientos se interpretarán en la hora oficial de Uruguay.

### 3.3.5. Rendimiento

**RNF-16 Tiempo de respuesta:** Las operaciones de consulta y de agenda deberán responder en menos de 3 segundos en condiciones normales de uso, sin contar el tiempo de red del usuario. Las cargas masivas y las estadísticas podrán demorar más, informando al usuario que la operación está en curso.

### 3.3.6. Disponibilidad y respaldo

**RNF-17 Disponibilidad:** Por tratarse de un prototipo, el sistema deberá estar disponible durante las instancias de demostración y evaluación. No se establece un objetivo de disponibilidad continua.

**RNF-18 Respaldo de la información:** La base de datos deberá contar con respaldos periódicos que permitan restaurar la información ante una pérdida de datos.

**RNF-19 Reconstrucción del esquema:** La estructura de la base de datos, incluidas sus restricciones e índices, deberá poder recrearse a partir de scripts versionados en el repositorio del proyecto, de modo que un entorno nuevo reproduzca las mismas reglas de integridad.

### 3.3.7. Usabilidad

**RNF-20 Idioma y formatos:** La interfaz estará en español. Las fechas se mostrarán en formato dd/mm/aaaa y las horas en formato de 24 horas.

**RNF-21 Diseño adaptable:** La aplicación web deberá adaptarse a pantallas de computadora, tableta y teléfono móvil.

**RNF-22 Mensajes al usuario:** Cada operación deberá informar su resultado. Ante un error, el mensaje indicará qué ocurrió y qué puede hacer el usuario, sin términos técnicos.

### 3.3.8. Notificaciones

**RNF-23 Canales de notificación:** Las notificaciones al socio mencionadas en los requerimientos se enviarán por correo electrónico y por la interfaz del sistema. También se enviarán como notificaciones push en la aplicación Android si el socio la instaló y otorgó el permiso correspondiente.

**RNF-24 Independencia de la operación:** Una falla en el envío de una notificación no deberá impedir ni revertir la operación que la originó.

**RNF-25 Recordatorio automático de consulta:** El sistema enviará al socio una notificación de recordatorio 24 horas antes de cada consulta Agendada, con especialidad, médico, fecha, hora y consultorio, por los canales definidos en RNF-24. Si la consulta pasa a Agendada con menos de 24 horas de anticipación, no se envía el recordatorio.

### 3.3.9. Mantenibilidad y portabilidad

**RNF-26 Parámetros configurables:** Los valores de la sección 3.1.3 deberán poder modificarse sin cambiar el código fuente. No se incluye una pantalla de administración de esos parámetros.

**RNF-27 Configuración por entorno:** El sistema deberá poder ejecutarse en distintos entornos (desarrollo, pruebas y demostración) modificando únicamente su configuración, sin cambios en el código ni en el artefacto desplegado.

**RNF-28 Tecnología del servidor:** El servidor deberá implementarse en Java, según lo establece la propuesta del proyecto.
