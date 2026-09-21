# TODO EL POC — Backend + Base de Datos

> Documento único que junta todo lo que se probó en esta POC: los tres
> backends Java, la conexión real a PostgreSQL (Supabase) y la comparación
> de tecnologías. Está pensado para que cualquiera del grupo lo lea de
> corrido sin tener que ir a buscar los otros archivos de `docs/poc`.
>
> **Sobre las capturas de pantalla:** este trabajo se hizo en un Codespace
> sin entorno gráfico (todo por terminal), así que no hay forma de sacar
> capturas reales de DBeaver ni de un navegador. En vez de inventar
> imágenes, se dejan los bloques de salida real de la terminal (`psql`,
> logs de arranque, respuestas de `curl`) como evidencia. Si alguien repite
> esto en su máquina con DBeaver, puede agregar sus propias capturas acá.

## 1. Objetivo

Probar de verdad las tres alternativas de backend en Java (Spring Boot,
Quarkus, Jakarta EE/GlassFish), conectar al menos una de ellas contra la
base PostgreSQL real del proyecto (Supabase) y dejar todo documentado para
poder elegir tecnología con datos concretos, no solo con lo que dice cada
página oficial.

## 2. Ambiente utilizado

- GitHub Codespaces, Linux (Ubuntu 24.04).
- Java: OpenJDK 25.0.2 (Microsoft build).
- Maven 3.9.13 (`mvn` del sistema y los `mvnw` de cada proyecto).
- Docker 29.3.0-1 (daemon funcionando en el Codespace).
- `psql` (PostgreSQL) 16.15.
- Rama de trabajo: `poc/backend-springboot`.
- Base real: PostgreSQL administrado por Supabase (pooler
  `aws-0-ca-central-1.pooler.supabase.com`, base `postgres`, esquema
  `"POC"`). Las credenciales **no** se guardaron en ningún archivo del
  repositorio: se usaron solo como variables de entorno temporales durante
  las pruebas (`DB_URL`, `DB_USER`, `DB_PASSWORD`), y se limpiaron de la
  sesión al terminar.

## 3. Conexión real a PostgreSQL (Supabase)

### 3.1 Cómo conectarse (DBeaver, para el resto del equipo)

En DBeaver, crear una conexión PostgreSQL con estos datos:

- Host: `aws-0-ca-central-1.pooler.supabase.com`
- Puerto: `5432`
- Base: `postgres`
- Usuario: `postgres.whocghntqkhmicabtoox`
- Esquema: `"POC"` (con comillas dobles, en mayúsculas)
- SSL: activado, modo `require`
- Contraseña: **no va en este documento ni en ningún archivo del repo**;
  se comparte por un canal aparte (chat privado del grupo, no por Git).

### 3.2 Prueba real de conexión (por terminal, sin DBeaver)

Como en el Codespace no hay entorno gráfico, la conexión se probó con
`psql`, pasando la contraseña únicamente por variable de entorno
(`PGPASSWORD`), nunca escrita en un archivo:

```bash
export PGPASSWORD='********'   # no se guarda en ningún archivo
psql "host=aws-0-ca-central-1.pooler.supabase.com port=5432 dbname=postgres user=postgres.whocghntqkhmicabtoox sslmode=require" \
  -c "SELECT current_database(), current_user, now();" \
  -c "\dn"
unset PGPASSWORD
```

Resultado real:

```
 current_database | current_user |              now
-------------------+--------------+-------------------------------
 postgres          | postgres     | 2026-09-11 17:07:45.998348+00
(1 row)

          List of schemas
      Name      |       Owner
----------------+-------------------
 POC            | postgres
 auth           | supabase_admin
 extensions     | postgres
 graphql        | supabase_admin
 graphql_public | supabase_admin
 pgbouncer      | pgbouncer
 public         | pg_database_owner
 realtime       | supabase_admin
 storage        | supabase_admin
 vault          | supabase_admin
(10 rows)
```

Conexión confirmada: el esquema `"POC"` existe y está accesible con el
usuario dado.

### 3.3 Tablas y datos reales encontrados

```sql
\dt "POC".*
SELECT count(*) FROM "POC".usuario;
SELECT count(*) FROM "POC".profesional;
SELECT count(*) FROM "POC".horario;
SELECT count(*) FROM "POC".reserva;
```

Resultado real:

```
            List of relations
 Schema |    Name     | Type  |  Owner
--------+-------------+-------+----------
 POC    | horario     | table | postgres
 POC    | profesional | table | postgres
 POC    | reserva     | table | postgres
 POC    | usuario     | table | postgres
(4 rows)

 usuarios: 8
 profesionales: 4
 horarios: 80
 reservas: 18
```

Y el resumen de disponibilidad (mismo tipo de consulta que
`database/poc-sql/02_consultar_datos.sql`):

```
 horarios | libres | ocupados
----------+--------+----------
       80 |     69 |       11
```

Los 4 profesionales reales en la base son: **Ana Gómez**, **Martín
Fernández**, **Valentina Castro** y **Pablo Núñez** (los datos de carga los
armó otra parte del equipo; en esta sesión solo se leyó, no se insertó ni
modificó nada).

No se hizo ningún `INSERT`, `UPDATE` ni `DELETE` sobre esta base: todas las
consultas de esta sección son de solo lectura.

### 3.4 Spring Boot conectado de verdad a Supabase

Se agregó un perfil nuevo `postgres` en Spring Boot
(`application-postgres.properties`) que lee la URL/usuario/contraseña
**solo** desde variables de entorno:

```properties
spring.autoconfigure.exclude=
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}
```

Se modificó `ProfesionalController` para que, si hay un `DataSource` real
disponible (perfil `postgres` activo), consulte la base de verdad usando
`ProfesionalJdbcDao` (el mismo SQL de
`database/poc-sql/backend/03_profesional_listar.sql`); si no hay
`DataSource` (perfil por defecto, sin credenciales), sigue devolviendo la
lista mock de antes.

Prueba real (variables de entorno seteadas solo en la terminal, nunca
guardadas en un archivo):

```bash
export DB_URL='jdbc:postgresql://aws-0-ca-central-1.pooler.supabase.com:5432/postgres?sslmode=require'
export DB_USER='postgres.whocghntqkhmicabtoox'
export DB_PASSWORD='********'
export SPRING_PROFILES_ACTIVE=postgres
java -jar target/poc-backend-0.0.1-SNAPSHOT.jar
```

Log real de arranque (recortado):

```
Started PocBackendApplication in 8.457 seconds
...
HikariPool-1 - Added connection org.postgresql.jdbc.PgConnection@f238e4f
...
Database JDBC URL [jdbc:postgresql://aws-0-ca-central-1.pooler.supabase.com:5432/postgres?sslmode=require]
Database version: 17.6
```

Y la respuesta real de `GET /profesionales`, ahora con datos de la base
(no mock):

```
[{"id":6,"nombre":"Ana Gómez"},{"id":7,"nombre":"Martín Fernández"},{"id":9,"nombre":"Pablo Núñez"},{"id":8,"nombre":"Valentina Castro"}]
HTTP:200
```

Coincide exactamente con lo que devolvió `psql` en la sección 3.3, así que
la conexión real funciona de punta a punta: Spring Boot → JDBC →
PostgreSQL (Supabase).

**Importante:** este perfil `postgres` es solo para pruebas locales. Nadie
debe subir sus credenciales reales a `application-postgres.properties` ni a
ningún otro archivo versionado; siempre por variable de entorno.

## 4. Prueba REST básica (`/hola`)

| Tecnología | Puerto | Endpoint | Resultado | Arranque (log interno) |
|---|---|---|---|---|
| Spring Boot | 8080 | `GET /hola` | `200`, `POC backend funcionando` | ~3.2 s |
| Quarkus | 8081 | `GET /hola` | `200`, `POC Quarkus funcionando` | ~1.1 s |
| Jakarta EE / GlassFish | 8082 | `GET /api/hola` (no `/poc-jakarta/api/hola`, ver problemas) | `200`, `POC Jakarta EE / GlassFish funcionando` | ~3.3 s |

## 5. Prueba de profesionales (las tres contra la base real)

Se implementó `GET /profesionales` en las tres tecnologías, basado en
`database/poc-sql/backend/03_profesional_listar.sql`. En esta segunda vuelta
se conectaron **las tres** contra la base real (antes solo Spring Boot):

- **Spring Boot**: con el perfil `postgres` activo, devuelve datos reales
  de Supabase via `ProfesionalJdbcDao` (ver sección 3.4). Sin ese perfil,
  sigue devolviendo la lista mock de 4 profesionales fijos.
- **Quarkus**: se agregó la extensión `quarkus-jdbc-postgresql` y un
  datasource Agroal configurado por variables de entorno (`DB_URL`,
  `DB_USER`, `DB_PASSWORD`). Probado real:

  ```
  GET http://localhost:8081/profesionales
  [{"id":6,"nombre":"Ana Gómez"},{"id":7,"nombre":"Martín Fernández"},{"id":9,"nombre":"Pablo Núñez"},{"id":8,"nombre":"Valentina Castro"}]
  HTTP:200
  ```

  Sin esas variables de entorno, sigue devolviendo la lista mock (no rompe
  `/hola` ni nada de lo que ya funcionaba).
- **Jakarta EE / GlassFish**: se agregó el driver `postgresql` al `pom.xml`
  del WAR y una conexión JDBC directa (`DriverManager`) usando las mismas
  variables de entorno. Probado real:

  ```
  GET http://localhost:8082/api/profesionales
  [{"id":6,"nombre":"Ana Gómez"},{"id":7,"nombre":"Martín Fernández"},{"id":9,"nombre":"Pablo Núñez"},{"id":8,"nombre":"Valentina Castro"}]
  HTTP:200
  ```

  Problema real encontrado acá: la primera versión tiraba
  `java.sql.SQLException: No suitable driver found`, porque GlassFish aisla
  el classloader de la webapp y `DriverManager` no encontraba el driver via
  `ServiceLoader`. Se solucionó agregando `Class.forName("org.postgresql.Driver")`
  antes de pedir la conexión.

Las tres devuelven exactamente los mismos 4 profesionales reales, lo que
confirma que las tres están leyendo de la misma base.

## 6. JDBC vs JPA (Spring Boot)

Se armaron dos implementaciones de referencia para `GET /profesionales`:

- `ProfesionalJdbcDao`: JDBC puro con `PreparedStatement`, reutilizando tal
  cual el SQL del POC de base de datos. **Esta es la que quedó conectada a
  la base real** (ver sección 3.4).
- `ProfesionalEntity` + `ProfesionalJpaRepository`: entidad JPA con un
  método derivado (`findAllByOrderByNombreAsc()`), sin escribir SQL a mano.
  Expuesta en un endpoint aparte, `GET /profesionales-jpa`, para no mezclar
  con la versión JDBC.

**Actualización:** se probó JPA contra la base real y también funcionó:

```
GET http://localhost:8080/profesionales-jpa
[{"nombre":"Ana Gómez","id":6},{"nombre":"Martín Fernández","id":7},{"nombre":"Pablo Núñez","id":9},{"nombre":"Valentina Castro","id":8}]
HTTP:200
```

Problema real encontrado: la primera prueba tiró `500` con
`relation "poc.profesional" does not exist`. Hibernate pasa los nombres de
esquema/tabla a minúsculas si no se le pide lo contrario, y el esquema real
es `"POC"` en mayúsculas y entre comillas. Se corrigió escribiendo
`@Table(name = "\`profesional\`", schema = "\`POC\`")` (con backticks), que le
dice a Hibernate que cite el identificador tal cual en vez de normalizarlo.

| Criterio | JDBC | JPA |
|---|---|---|
| Cantidad de código | Más líneas (conexión, `PreparedStatement`, `ResultSet` a mano) | Menos líneas (entidad + interfaz) |
| Control sobre el SQL | Total | Ninguno en el método derivado |
| Reutilización del SQL del POC de base de datos | Directa | Hay que traducirlo a JPQL o nombres de método |
| Mantenimiento | Cambios de columnas se tocan a mano | Se reflejan solo en la entidad |
| Se probó contra la base real | **Sí** (sección 3.4) | **Sí**, una vez corregido el nombre de esquema |
| Problema real encontrado | Ninguno particular | Esquema en mayúsculas sin citar (ver arriba) |

## 7. Horarios y reservas (Spring Boot, contra la base real)

Se conectaron los tres endpoints que faltaban, todos en Spring Boot y todos
probados contra la base real de Supabase (usuario real id 7 = Martina
Silva, horario real id 102, libre en el momento de la prueba):

- `GET /profesionales/{id}/horarios` (`HorarioJdbcDao`, basado en
  `08_horarios_disponibles.sql`): probado con `GET /profesionales/8/horarios`
  → `200 OK`, devolvió 3 horarios reales y libres del profesional 8.
- `POST /reservas` (`ReservaJdbcDao.crear`, basado en `09_reserva_alta.sql`,
  con un `NOT EXISTS` agregado para no permitir reservar dos veces el mismo
  horario):
  ```
  POST /reservas {"usuarioId":7,"horarioId":102} -> 201, reserva id 28, estado ACTIVA
  POST /reservas {"usuarioId":8,"horarioId":102} -> 409 Conflict (mismo horario)
  ```
- `PATCH /reservas/{id}/cancelacion` (`ReservaJdbcDao.cancelar`, basado en
  `10_reserva_cancelar.sql`):
  ```
  PATCH /reservas/28/cancelacion {"usuarioId":7} -> 200, estado CANCELADA
  ```
- `GET /mis-reservas?usuarioId=7` (`ReservaJdbcDao.listarPorUsuario`,
  basado en `11_reservas_usuario.sql`): devolvió el historial real del
  usuario 7, incluida la reserva recién cancelada y otras reservas previas
  ya cargadas en la base.

Sin el perfil `postgres` activo, estos mismos endpoints siguen funcionando
en modo mock (como antes), excepto `PATCH /reservas/{id}/cancelacion`, que
sin base real devuelve `501 Not Implemented` (no tiene sentido cancelar por
id sin un almacén persistente).

## 8. Docker

Se armó un `Dockerfile` mínimo para cada tecnología.

| Tecnología | Build | Tamaño imagen | Arranque en contenedor | Endpoint |
|---|---|---|---|---|
| Spring Boot | ~6 s | 593 MB | ~4.2 s (log interno) | `GET /hola` → `200` |
| Quarkus | ~4 s | 532 MB (la más liviana) | ~2 s | `GET /hola` → `200` |
| Jakarta EE / GlassFish | ~10 s | 673 MB (la más pesada) | ~3.3 s | `GET /api/hola` → `200` |

Problema real encontrado: los tres `Dockerfile` fallaban al principio con
`UnsupportedClassVersionError` usando `eclipse-temurin:21-jre`, porque los
tres proyectos compilan con Java 25. Se corrigió usando
`eclipse-temurin:25-jre` en los tres.

## 9. Comparación de tecnologías

| Criterio | Spring Boot | Quarkus | Jakarta EE / GlassFish |
|---|---|---|---|
| Facilidad de instalación/configuración | Alta, venía armado | Baja: faltaba el `pom.xml` completo, hubo que crearlo | Media: hay que armar `pom.xml` con `packaging war` y GlassFish embebido aparte |
| Curva de aprendizaje | Baja/media (mucho autoconfigure "mágico") | Baja (JAX-RS estándar) | Media/alta (concepto de contenedor de aplicaciones) |
| Crear un REST simple | Muy simple | Simple | Simple, con un paso extra (`@ApplicationPath`) |
| Compilación | OK, ~8-13 s | OK, ~13-17 s (con caché baja) | OK, ~2-3 s |
| Tiempo de inicio (sin Docker) | ~3.2 s | ~1.1-1.3 s | ~3.3 s |
| Tamaño de imagen Docker | 593 MB | 532 MB | 673 MB |
| Conexión a PostgreSQL real | **Probada y funcionando** (JDBC y JPA, más reservas/cancelación/historial) | **Probada y funcionando** (JDBC via Agroal) | **Probada y funcionando** (JDBC directo con `DriverManager`) |
| JDBC | Probado contra base real (profesionales, horarios, reservas, cancelación, historial) | Probado contra base real (profesionales) | Probado contra base real (profesionales) |
| JPA / ORM | Probado contra base real, tras corregir el esquema `"POC"` | No probado | No probado |
| Problemas encontrados | Autoconfigure de datasource sin BD; paquetes de autoconfigure cambiados en Spring Boot 4; JPA con esquema en mayúsculas | Faltaba `pom.xml`; faltaba `quarkus-resteasy-jackson` para JSON | Context root real distinto al esperado (`/` en vez de `/poc-jakarta`); `DriverManager` no encontraba el driver por aislamiento de classloader |
| Adecuación al proyecto | Buena, ya tiene resuelta la conexión a PostgreSQL (JDBC y JPA) y es la tecnología más conocida por el grupo | Buena para performance, ya conectada también, pero suma una tecnología nueva | Más pesada de configurar (hubo que resolver el driver a mano) para el tiempo del proyecto |

Ahora **las tres tecnologías** quedaron probadas contra la base PostgreSQL
real del proyecto (no solo Spring Boot como en la vuelta anterior). Aun así
Spring Boot es la que tiene el circuito más completo (profesionales,
horarios, reservar, cancelar e historial, más JDBC y JPA), y sigue siendo
la tecnología con la que el grupo tiene más experiencia.

## 10. Problemas encontrados (resumen)

- Spring Boot no arrancaba (test ni jar) por falta de datasource, aunque el
  `pom.xml` ya traía `data-jpa` + `postgresql`. Se corrigió con
  `spring.autoconfigure.exclude` en el perfil por defecto.
- Los nombres de paquete de autoconfigure de Spring Boot 4.1.1 cambiaron
  respecto a versiones anteriores.
- Quarkus no tenía `pom.xml` en el repo.
- Quarkus con `quarkus-resteasy` solo no devuelve JSON, faltaba
  `quarkus-resteasy-jackson`.
- El WAR de Jakarta EE se despliega en `/`, no en `/poc-jakarta`.
- Los tres `Dockerfile` fallaban con `eclipse-temurin:21-jre` por la
  versión de Java (se compiló todo con Java 25).
- JPA en Spring Boot tiraba `relation "poc.profesional" does not exist`
  porque Hibernate no citaba el esquema `"POC"` (mayúsculas); se corrigió
  con backticks en `@Table`.
- Jakarta EE con `DriverManager` tiraba `No suitable driver found` por
  aislamiento de classloader en GlassFish; se corrigió registrando el
  driver a mano con `Class.forName("org.postgresql.Driver")`.
- Ninguno de estos problemas se "arregló a lo loco": cada uno está
  documentado acá y en `docs/poc/resultados-backend.md` con la causa y la
  corrección aplicada.

## 11. Qué quedó pendiente

Casi todo lo que faltaba en la vuelta anterior ya se hizo (conexión real en
las tres tecnologías, JPA real, reservas/cancelación/historial real, un
test automatizado). Queda:

- Definir con el grupo la tecnología final (todo indica que la idea es
  Spring Boot, dado el nombre de la rama y que es la que tiene el circuito
  más completo contra la base real).
- Agregar más tests automatizados, sobre todo para Quarkus y Jakarta EE (por
  ahora solo hay uno, para el conflicto de reservas en modo mock de Spring
  Boot; no se corrió ningún test contra la base real para no dejar técnicas
  de test corriendo con credenciales reales en el pipeline).
- Extender `GET /profesionales/{id}/horarios`, `POST /reservas`,
  `PATCH /reservas/{id}/cancelacion` y `GET /mis-reservas` a Quarkus y
  Jakarta EE si esas tecnologías siguen en carrera (por ahora esas tres
  operaciones solo están en Spring Boot).
- Configurar un `Connection Pool`/`JDBC Resource` real en GlassFish (la
  conexión actual con `DriverManager` es aceptable para una POC, pero no es
  lo recomendado para producción: no reutiliza conexiones).
- Sacar capturas de pantalla reales de DBeaver cuando alguien lo pruebe
  desde una máquina con entorno gráfico (acá no fue posible).
- Decidir qué hacer con la reserva de prueba que quedó en la base real
  (id 28, usuario 7, horario 102): se dejó en estado `CANCELADA` a
  propósito (no se borró la fila), tal como quedaría después de un uso
  real de la aplicación.

## 12. Dónde está cada cosa

- `docs/poc/resultados-backend.md`: informe detallado de la POC de
  backend (fases 1 a 9, antes de conectar la base real).
- `docs/poc/comandos-pruebas-backend.md`: comandos para repetir las pruebas
  REST de cada tecnología.
- `database/poc-sql/`: SQL de referencia del POC de base de datos.
- Este archivo (`TODOELPOC.md`): resumen de todo, incluida la conexión real
  a PostgreSQL.
