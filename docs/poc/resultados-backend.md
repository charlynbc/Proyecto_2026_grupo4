# POC Backend

## Objetivo

Comparar en la práctica tres alternativas de backend en Java (Spring Boot,
Quarkus y Jakarta EE con GlassFish) para elegir con qué seguir el proyecto de
reserva de órdenes de la institución médica. La idea no es leer documentación
y opinar, sino ejecutar pruebas parecidas en las tres y anotar lo que
realmente pasó.

## Ambiente utilizado

- GitHub Codespaces sobre Linux (Ubuntu 24.04).
- Java: OpenJDK 25.0.2 (Microsoft build), instalado con SDKMAN.
- Maven: Apache Maven 3.9.13 (`mvn` del sistema) y los wrappers `mvnw` de cada
  proyecto.
- PostgreSQL client: `psql` 16 (no se usó en esta sesión, no hay una base real
  conectada).
- Docker: 29.3.0-1, con el daemon funcionando en el Codespace.
- Rama de trabajo: `poc/backend-springboot`.
- No hay ninguna credencial real cargada en el repositorio, solo
  `.env.example` con valores de ejemplo.

## Tecnologías evaluadas

### Spring Boot

Framework más usado en la carrera, con Spring Initializr y mucho de
"autoconfigure" por detrás. El proyecto ya venía armado con
`spring-boot-starter-webmvc`, `spring-boot-starter-data-jpa` y el driver de
PostgreSQL en el `pom.xml`.

### Quarkus

Framework pensado para arrancar rápido y consumir poca memoria, con JAX-RS
estándar. En este repo solo estaba el código fuente, sin `pom.xml`.

### Jakarta EE / GlassFish

El enfoque más "clásico": un WAR desplegado en un servidor de aplicaciones
(en este caso GlassFish embebido, corrido como un jar). Usa JAX-RS estándar
igual que Quarkus.

## Prueba REST

### Spring Boot

#### Qué probé

- `./mvnw test`
- `./mvnw package`
- Levantar el jar generado y pegarle a `GET http://localhost:8080/hola`.

#### Cómo lo probé

Entré a `backend/poc-springboot`, corrí los comandos de Maven y después ejecuté
`java -jar target/poc-backend-0.0.1-SNAPSHOT.jar`. Una vez que vi el log de "Started
PocBackendApplication", probé con:

```
curl -s -o /tmp/spring_body.txt -w "HTTP_CODE:%{http_code} TIME:%{time_total}\n" http://localhost:8080/hola
```

#### Resultado

- `./mvnw test`: **exitoso** (después de una corrección, ver más abajo). Tardó
  aproximadamente 8 segundos.
- `./mvnw package`: **exitoso**, generó el jar en `target/poc-backend-0.0.1-SNAPSHOT.jar`.
- Arranque de la app: el propio log de Spring Boot dice
  `Started PocBackendApplication in 3.273 seconds`.
- Petición `GET /hola`: código HTTP `200`, cuerpo `POC backend funcionando`,
  tiempo de respuesta ~0.14 segundos.

#### Problemas encontrados

El `pom.xml` ya traía `spring-boot-starter-data-jpa` y el driver de `postgresql`,
pero en ningún lado hay un datasource configurado (ni debería haberlo, porque no
hay credenciales reales en el repo). Esto hizo que:

1. El test `contextLoads` fallara al arrancar el contexto de Spring, porque Spring
   Boot intenta crear automáticamente un `DataSource` y no encuentra ni URL ni driver.
2. Al ejecutar el jar pasaba exactamente lo mismo: la aplicación no arrancaba y
   tiraba `Failed to configure a DataSource`.

Como corrección, agregué la propiedad `spring.autoconfigure.exclude` para
desactivar el autoconfigure de `DataSource`/JPA/Hibernate, tanto en
`src/main/resources/application.properties` como en un `application.properties`
nuevo dentro de `src/test/resources` (no existía). Esto es una solución
provisoria para poder levantar el "hola mundo" sin tocar nada de PostgreSQL;
cuando conectemos la base real, esa exclusión se va a tener que sacar.

Un detalle no menor: Spring Boot 4.1.1 movió las clases de autoconfigure a
paquetes nuevos (por ejemplo `org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration`
en vez del paquete clásico `org.springframework.boot.autoconfigure.jdbc...` que
aparece en la mayoría de los tutoriales viejos). El primer intento de exclusión
falló por usar el nombre de paquete antiguo.

#### Qué aprendí

Que tener una dependencia en el `pom.xml` (como `data-jpa`) ya alcanza para que
Spring Boot intente autoconfigurar cosas, aunque el proyecto todavía no use nada
de eso. También aprendí que hay que fijarse bien la versión del framework antes
de copiar nombres de clases de internet, porque en Spring Boot 4 cambiaron de
paquete varias autoconfiguraciones.

### Quarkus

#### Qué probé

- Compilar el proyecto con Maven.
- Empaquetarlo.
- Levantarlo y probar `GET http://localhost:8081/hola`.

#### Cómo lo probé

Al entrar a `backend/poc-quarkus` me encontré con que **no existía `pom.xml`**,
solo estaba el código fuente (`HolaResource.java` y `application.properties` con
`quarkus.http.port=8081`). No hay `mvnw` tampoco. Sin `pom.xml` no hay forma de
compilar nada, así que antes de poder probar tuve que crear uno.

Armé un `pom.xml` mínimo usando el BOM de Quarkus (versión 3.17.5) con la
dependencia `quarkus-resteasy`, que es compatible con las anotaciones JAX-RS
(`jakarta.ws.rs`) que ya estaban en `HolaResource.java`. Con eso corrí:

```
mvn compile
mvn package
java -jar target/quarkus-app/quarkus-run.jar
```

Y después:

```
curl -s -o /tmp/quarkus_body.txt -w "HTTP_CODE:%{http_code} TIME:%{time_total}\n" http://localhost:8081/hola
```

#### Resultado

- Compilación: **exitosa** una vez agregado el `pom.xml` (~17 segundos).
- Empaquetado: **exitoso** (~16 segundos), generó `target/quarkus-app/quarkus-run.jar`.
- Arranque: el log de Quarkus dice
  `poc-quarkus 1.0.0-SNAPSHOT on JVM ... started in 1.082s`.
- Petición `GET /hola`: código HTTP `200`, cuerpo `POC Quarkus funcionando`,
  tiempo de respuesta ~0.12 segundos.

#### Problemas encontrados

El problema principal fue que faltaba el `pom.xml` completo, algo que no
esperaba porque en la consigna decía que el laboratorio ya estaba preparado.
Tuve que crear el archivo yo mismo, así que dejo esto documentado: el
`pom.xml` de Quarkus no es "original" del POC preparado, lo generé para poder
compilar y correr el código que ya estaba escrito.

#### Qué aprendí

Que Quarkus arranca notablemente más rápido que Spring Boot en este mismo tipo
de prueba (poco más de 1 segundo contra poco más de 3 segundos), al menos con
un endpoint tan simple. También aprendí a armar un `pom.xml` de Quarkus desde
cero usando el BOM, sin pasar por el generador web (code.quarkus.io).

### Jakarta EE / GlassFish

#### Qué probé

- Generar el WAR (esto ya estaba comprobado antes de esta sesión).
- Levantar GlassFish embebido y desplegar el WAR con el script existente
  `scripts/run-glassfish.sh`.
- Probar el endpoint real (no el que suponíamos de entrada).

#### Cómo lo probé

Antes de probar, miré el código: `RestApplication.java` tiene
`@ApplicationPath("/api")` y `HolaResource.java` tiene `@Path("/hola")`, o sea
que el recurso cuelga de `/api/hola` dentro del contexto de la aplicación.

Corrí el script:

```
bash scripts/run-glassfish.sh
```

que hace `mvn package` y después levanta GlassFish embebido
(`glassfish-embedded-all-8.0.4.jar`) con el WAR en el puerto 8082.

#### Resultado

- Empaquetado del WAR: **exitoso** (ya se sabía de antes, se reconfirmó).
- GlassFish arrancó bien. El log muestra:
  `GlassFish (commit: null) startup time: Embedded (2,609 ms), startup services (690 ms), total (3,299 ms)`
- El WAR se desplegó, pero en el log dice textualmente:
  `Application poc-jakarta.war deployed at context root "/"` y
  `poc-jakarta was successfully deployed in 2,853 milliseconds.`
  O sea que **no** quedó montado en `/poc-jakarta` sino en la raíz `/`.
- Por eso, la ruta que la consigna proponía como probable
  (`GET /poc-jakarta/api/hola`) devolvió **404**.
- La ruta real que respondió fue `GET http://localhost:8082/api/hola`, con
  código HTTP `200`, cuerpo `POC Jakarta EE / GlassFish funcionando` y un
  tiempo de respuesta de ~0.19 segundos.

#### Problemas encontrados

El principal fue justamente ese: la ruta "probable" que se planteaba en la
consigna no era la real. GlassFish embebido, con la configuración actual,
despliega el WAR en el context root `/` y no usa el nombre del WAR
(`poc-jakarta`) como contexto. Esto no lo arreglé porque no hace falta romper
nada: simplemente hay que usar la ruta correcta al momento de probar o
documentar (`/api/hola` en vez de `/poc-jakarta/api/hola`).

#### Qué aprendí

Que no hay que asumir el context root de un despliegue en GlassFish embebido,
hay que fijarse en el log de arranque. También quedó claro por qué conviene
armar la ruta juntando `@ApplicationPath` + `@Path` del recurso, en vez de
adivinar en base al nombre del artefacto.

## Prueba de profesionales

Se implementó `GET /profesionales` en las tres tecnologías, tomando como
referencia la consulta `database/poc-sql/backend/03_profesional_listar.sql`
(mismas columnas: `id`, `nombre`).

**Importante:** en esta sesión no hay conexión PostgreSQL configurada
mediante variables de entorno (no hay credenciales reales en el repo), así
que en los tres casos la respuesta es una **lista fija en memoria (mock)**,
no datos reales de la base. Esto está señalado en comentarios dentro del
código de cada controlador/recurso.

Resultado real de las pruebas (mismo cuerpo JSON en las tres):

```
[{"id":1,"nombre":"Ana Beltrán"},{"id":2,"nombre":"Pablo Suárez"},{"id":3,"nombre":"Valentina Ríos"},{"id":4,"nombre":"Ignacio Ferreira"}]
```

- Spring Boot: `GET http://localhost:8080/profesionales` → `200 OK`.
- Quarkus: `GET http://localhost:8081/profesionales` → `200 OK` (hubo que
  agregar `quarkus-resteasy-jackson`, porque `quarkus-resteasy` solo no trae
  soporte de JSON).
- Jakarta EE / GlassFish: `GET http://localhost:8082/api/profesionales` →
  `200 OK` (acá el JSON lo serializa JSON-B, que ya viene con
  `jakarta.jakartaee-api`).

## PostgreSQL

No se conectó a ninguna base PostgreSQL real en esta sesión. Solo existe
`.env.example` con variables de ejemplo (`DB_URL`, `DB_USER`, `DB_PASSWORD`),
sin valores reales. Como no había credenciales cargadas mediante variables de
entorno, no se intentó ninguna conexión, tal como se pidió.

Las consultas de `database/poc-sql/backend` (`03_profesional_listar.sql`,
`08_horarios_disponibles.sql`, `09_reserva_alta.sql`, etc.) se usaron
únicamente como referencia de forma/columnas para armar los DTOs mock y el
DAO/entidad de la comparación JDBC vs JPA.

## JDBC

Se armó `ProfesionalJdbcDao` (paquete `comparacionjdbcjpa` en
`poc-springboot`), que reutiliza tal cual el SQL de
`03_profesional_listar.sql` con un `PreparedStatement`:

```java
private static final String SQL = """
        SELECT id, nombre
        FROM "POC".profesional
        ORDER BY nombre, id
        """;
```

No se ejecutó contra una base real (no hay `DataSource` configurado), quedó
como referencia de código para comparar contra JPA. Es explícito: hay que
abrir la conexión, armar el `PreparedStatement`, iterar el `ResultSet` a
mano y cerrar todo con try-with-resources.

## JPA / Hibernate

Se armó una entidad `ProfesionalEntity` (`@Entity`, `@Table(name = "profesional", schema = "POC")`)
y un repository `ProfesionalJpaRepository extends JpaRepository<...>` con un
método derivado `findAllByOrderByNombreAsc()`, sin escribir ningún SQL a
mano.

Tampoco se activó contra una base real: de hecho, en `application.properties`
tuvimos que **excluir** el autoconfigure de JPA/Hibernate para que la app
arrancara sin datasource (ver "Prueba REST" de Spring Boot), así que estas
clases quedan compiladas pero no se instancian como beans todavía.

## Comparación JDBC vs JPA

| Criterio | JDBC (`ProfesionalJdbcDao`) | JPA (`ProfesionalEntity` + `ProfesionalJpaRepository`) |
|---|---|---|
| Cantidad de código | Más líneas: hay que abrir conexión, `PreparedStatement`, recorrer `ResultSet` a mano | Menos líneas: la entidad y una interfaz con un método derivado alcanzan |
| Control sobre el SQL | Total, es el mismo SQL que ya usa el equipo de base de datos | Ninguno en el método derivado; si se necesita algo más específico hay que usar `@Query` |
| Facilidad de lectura | Se entiende exactamente qué se ejecuta contra la base | Hay que saber cómo Spring Data traduce el nombre del método a SQL |
| Dificultad | Baja si ya se sabe SQL y JDBC | Baja para casos simples, sube con relaciones o consultas complejas |
| Reutilización del SQL existente | Directa, se copia y pega el `.sql` del POC de base de datos | Indirecta, hay que "traducirlo" a JPQL o a nombres de método |
| Mantenimiento | Cambios de columnas rompen el SQL a mano, hay que tocarlo manualmente | Cambios de columnas se reflejan solo en la entidad |
| Relaciones (profesional-horario-reserva) | Hay que resolverlas a mano con joins escritos por nosotros | Se pueden modelar con `@OneToMany`/`@ManyToOne`, pero agrega complejidad |
| Manejo de errores | Hay que capturar `SQLException` explícitamente | Las excepciones de Spring Data ya vienen traducidas a excepciones de Spring |
| Adecuación al proyecto | Encaja bien porque ya existe todo el SQL armado en `database/poc-sql` | Encaja bien si el equipo prefiere no escribir SQL a mano |

Ninguna de las dos opciones se probó contra PostgreSQL real en esta sesión;
la comparación es sobre el código en sí, no sobre tiempos de ejecución.

## Prueba de horarios

Se implementó `GET /profesionales/{id}/horarios` solo en Spring Boot (no en
Quarkus ni en Jakarta EE, para no repetir tres veces lo mismo en esta etapa),
tomando como referencia `08_horarios_disponibles.sql`. También es mock, con
una lista fija en memoria filtrada por `profesionalId`.

Prueba real: `GET http://localhost:8080/profesionales/1/horarios` → `200 OK`,
devolvió 2 horarios mock del profesional 1.

## Prueba de reserva

Se implementó `POST /reservas` solo en Spring Boot, tomando como referencia
`09_reserva_alta.sql`. Como no hay base real, el "ocupado/libre" se maneja
con un `Set` en memoria (se pierde al reiniciar la app). Esto no modifica
ninguna base remota.

Pruebas reales:

1. `POST /reservas` con `{"usuarioId":1,"horarioId":101}` → `201 Created`,
   devolvió la reserva creada con estado `ACTIVA`.
2. `POST /reservas` con `{"usuarioId":2,"horarioId":101}` (mismo horario) →
   `409 Conflict`, sin cuerpo.

Esto muestra cómo se manejaría el conflicto en la versión real: antes de
insertar, hay que comprobar que el horario no tenga ya una reserva activa
(la misma idea que aplica `08_horarios_disponibles.sql` al filtrar los
horarios disponibles) y devolver `409` si ya está ocupado.

## Docker

Se armó un `Dockerfile` mínimo para cada tecnología y se construyeron y
levantaron los tres contenedores.

| Tecnología | Tiempo de build | Tamaño de imagen | Tiempo de arranque en contenedor | Resultado del endpoint |
|---|---|---|---|---|
| Spring Boot | ~6.2 s (con capas ya cacheadas) | 593 MB | Log interno: `Started ... in 4.232 seconds`; contenedor listo a los ~8 s desde el `docker run` | `GET /hola` → `200`, `POC backend funcionando` |
| Quarkus | ~4.3 s | 532 MB | Log interno: `started in 1.988s`; contenedor listo a los ~3 s desde el `docker run` | `GET /hola` → `200`, `POC Quarkus funcionando` |
| Jakarta EE / GlassFish | ~10 s | 673 MB | Log interno: `total (3,300 ms)`; contenedor listo a los ~7 s desde el `docker run` | `GET /api/hola` → `200`, `POC Jakarta EE / GlassFish funcionando` |

Problema encontrado: al principio se armaron los tres `Dockerfile` con
`eclipse-temurin:21-jre`, y los tres contenedores fallaban con
`UnsupportedClassVersionError` (class file version 69.0, la imagen solo
soporta hasta 65.0). Los tres proyectos compilan con Java 25
(`java.version`/`maven.compiler.release` en cada `pom.xml`), así que hubo que
cambiar la imagen base a `eclipse-temurin:25-jre` en los tres Dockerfiles.

No se hizo ningún despliegue en la nube ni configuración de producción, solo
se corrió cada contenedor en local con `docker run` y se probó con curl.

## Comparación general

| Criterio | Spring Boot | Quarkus | Jakarta EE / GlassFish |
|---|---|---|---|
| Facilidad de instalación | Alta, venía armado con Spring Initializr | Baja: faltaba el `pom.xml` completo | Media: hay que saber armar `pom.xml` con `packaging war` y manejar GlassFish embebido aparte |
| Configuración inicial | Poca, casi todo por autoconfigure | Poca una vez con el `pom.xml` correcto | Media, hay que entender `@ApplicationPath` y el WAR |
| Curva de aprendizaje | Baja/media (mucha "magia" de autoconfigure que hay que entender) | Baja (JAX-RS estándar, arranca rápido) | Media/alta (concepto de contenedor de aplicaciones) |
| Facilidad para crear REST | Muy simple (`@RestController` + `@GetMapping`) | Simple (`@Path` + `@GET` estándar) | Simple pero con un paso extra (`@ApplicationPath`) |
| Cantidad de código | Poca para lo básico, pero el `pom.xml` ya trae bastante | Poca, una vez resuelto el `pom.xml` | Poca, el JAX-RS es liviano |
| Facilidad de debugging | Buena, mensajes de error de Spring bastante descriptivos (el de datasource lo fue) | Buena, mensajes de Quarkus también claros | Media, el log de GlassFish es más verboso y hay que buscar bien la línea del context root |
| Compilación | OK, ~8-13 s con tests | OK, ~13-17 s (bajó a caché la segunda vez) | OK, ~2-3 s (WAR chico, casi sin dependencias) |
| Tiempo de inicio (directo, sin Docker) | ~3.2 s | ~1.1-1.3 s | ~3.3 s |
| Documentación | Mucha, pero a veces desactualizada para versiones nuevas (nos pasó con los paquetes de autoconfigure) | Buena y bastante al día | Más dispersa entre Jakarta EE spec y GlassFish embebido |
| Comunidad | Muy grande | Grande y activa, más chica que Spring | Más chica, más orientada a entornos empresariales tradicionales |
| PostgreSQL | Dependencias ya en el `pom.xml`, falta conectar | Requiere agregar `quarkus-jdbc-postgresql` (no probado) | Requiere configurar `Connection Pool`/`JDBC Resource` en GlassFish (no probado) |
| JDBC | Probado como referencia de código (`ProfesionalJdbcDao`), no contra base real | No probado en esta sesión | No probado en esta sesión |
| JPA / ORM | Probado como referencia de código (`ProfesionalEntity` + repository), no contra base real | No probado en esta sesión | No probado en esta sesión |
| Docker | Imagen de 593 MB, arranque contenedor ~4.2 s | Imagen de 532 MB (la más liviana de las tres), arranque ~2 s | Imagen de 673 MB (la más pesada), arranque ~3.3 s |
| Testing | `./mvnw test` con JUnit + Spring Test, tuvimos que ajustar el `application.properties` de test | No se probaron tests automatizados en esta sesión | No se probaron tests automatizados en esta sesión |
| Mantenimiento | Requiere estar atento a los cambios de Spring Boot entre versiones mayores (nos pasó justo con la 4.1.1) | Parece más estable entre versiones para este tipo de casos simples | Estable, pero cualquier cambio de servidor de aplicaciones puede afectar el despliegue |
| Claridad de arquitectura | Clara, Controller/Service/Repository es un patrón conocido por el grupo | Clara, misma idea con JAX-RS | Un poco menos clara para quien no conoce Jakarta EE/servidores de aplicaciones |
| Adecuación al tiempo del proyecto | Buena, hay mucho ejemplo y soporte para resolver dudas rápido | Buena, pero suma una tecnología nueva para el grupo | Más pesada para armar en el tiempo que tenemos |
| Facilidad para que el grupo aprenda | Alta, ya es la tecnología con la que más se trabajó en la carrera | Media, conceptos similares a Spring pero herramientas distintas | Media/baja, requiere entender el modelo de servidor de aplicaciones |

No se eligió ganador solo por rendimiento: Quarkus arrancó más rápido y generó
la imagen más liviana, pero Spring Boot es con la que el grupo tiene más
experiencia y ya tiene resuelta la parte de PostgreSQL en el `pom.xml`.

## Problemas encontrados

- Spring Boot no arrancaba (test ni jar) por falta de datasource, aunque el
  `pom.xml` ya traía `data-jpa` + `postgresql`. Se solucionó excluyendo el
  autoconfigure correspondiente.
- Los nombres de paquete de autoconfigure de Spring Boot 4.1.1 cambiaron
  respecto a las versiones anteriores; el primer intento de exclusión usó
  los nombres viejos y no funcionó.
- Quarkus no tenía `pom.xml` en el repo, solo el código fuente.
- Quarkus con `quarkus-resteasy` solo no devuelve JSON; hubo que sumar
  `quarkus-resteasy-jackson`.
- El WAR de Jakarta EE se despliega en el context root `/` y no en
  `/poc-jakarta`, distinto de lo que se suponía inicialmente.
- Los tres `Dockerfile` fallaban al principio con `UnsupportedClassVersionError`
  porque se usó `eclipse-temurin:21-jre` con jars compilados para Java 25.

## Conclusión

Con las pruebas reales hechas hasta ahora, las tres tecnologías cumplen lo
básico (REST simple, endpoint mock de profesionales, Docker). Ninguna vino
"lista para andar" sin ajustes: cada una tuvo al menos un problema real que
hubo que resolver y documentar. Spring Boot tiene a favor la familiaridad del
grupo y que el `pom.xml` ya trae lo necesario para PostgreSQL. Quarkus se
destacó en tiempo de arranque y tamaño de imagen. Jakarta EE/GlassFish fue el
más pesado de configurar y el que más dudas generó sobre el despliegue real.
Esto **no** es una decisión definitiva del grupo, es solo lo que se pudo
comprobar ejecutando las pruebas.

## Próximos pasos

- Definir con el grupo si se sigue con Spring Boot (coherente con el nombre
  de la rama `poc/backend-springboot`) o se sigue evaluando alguna otra.
- Conectar una base PostgreSQL real (con variables de entorno, sin
  credenciales en el repo) y repetir las pruebas de JDBC vs JPA contra datos
  reales, no mock.
- Si se sigue con Quarkus como alternativa, agregar `quarkus-jdbc-postgresql`
  y repetir la prueba de profesionales contra la base real.
- Si se sigue con Jakarta EE, configurar un `Connection Pool`/`JDBC Resource`
  en GlassFish.
- Extender `GET /profesionales/{id}/horarios` y `POST /reservas` a Quarkus y
  Jakarta EE si esas tecnologías siguen en carrera.
- Escribir tests automatizados para los endpoints mock antes de reemplazarlos
  por la versión con base real.
- Revisar seguridad de contenedores (usuario no root, versión de imagen base)
  antes de pensar en un despliegue real, algo que no se evaluó en esta POC.
