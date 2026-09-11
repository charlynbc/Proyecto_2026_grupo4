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

## 5. Prueba de profesionales (mock vs real)

Se implementó `GET /profesionales` en las tres tecnologías, basado en
`database/poc-sql/backend/03_profesional_listar.sql`:

- **Spring Boot**: con el perfil `postgres` activo, devuelve datos
  **reales** de Supabase (ver sección 3.4). Sin ese perfil, devuelve una
  lista mock de 4 profesionales fijos.
- **Quarkus**: por ahora devuelve mock (no se conectó a Postgres en esta
  sesión; falta agregar `quarkus-jdbc-postgresql`).
- **Jakarta EE / GlassFish**: por ahora devuelve mock (falta configurar un
  `Connection Pool`/`JDBC Resource` en GlassFish).

## 6. JDBC vs JPA (Spring Boot)

Se armaron dos implementaciones de referencia para `GET /profesionales`:

- `ProfesionalJdbcDao`: JDBC puro con `PreparedStatement`, reutilizando tal
  cual el SQL del POC de base de datos. **Esta es la que quedó conectada a
  la base real** (ver sección 3.4).
- `ProfesionalEntity` + `ProfesionalJpaRepository`: entidad JPA con un
  método derivado (`findAllByOrderByNombreAsc()`), sin escribir SQL a mano.
  Quedó como referencia de código, no se activó contra la base real en
  esta sesión.

| Criterio | JDBC | JPA |
|---|---|---|
| Cantidad de código | Más líneas (conexión, `PreparedStatement`, `ResultSet` a mano) | Menos líneas (entidad + interfaz) |
| Control sobre el SQL | Total | Ninguno en el método derivado |
| Reutilización del SQL del POC de base de datos | Directa | Hay que traducirlo a JPQL o nombres de método |
| Mantenimiento | Cambios de columnas se tocan a mano | Se reflejan solo en la entidad |
| Se probó contra la base real | **Sí** (sección 3.4) | No en esta sesión |

## 7. Horarios y reservas (mock, solo Spring Boot)

- `GET /profesionales/{id}/horarios`: mock en memoria, basado en
  `08_horarios_disponibles.sql`. Probado: `200 OK`.
- `POST /reservas`: mock en memoria (un `Set` que se pierde al reiniciar),
  basado en `09_reserva_alta.sql`. Probado:
  - Primera reserva de un horario → `201 Created`.
  - Segunda reserva del mismo horario → `409 Conflict` (simula el caso real
    de horario ya ocupado).

No se implementó todavía contra la base real; son mock para probar el
circuito Controller → Service → JSON antes de conectar todo.

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
| Conexión a PostgreSQL real | **Probada y funcionando** (Spring Boot + JDBC) | No probada | No probada |
| JDBC | Probado contra base real | No probado | No probado |
| JPA / ORM | Código de referencia, no probado contra base real | No probado | No probado |
| Problemas encontrados | Autoconfigure de datasource sin BD; paquetes de autoconfigure cambiados en Spring Boot 4 | Faltaba `pom.xml`; faltaba `quarkus-resteasy-jackson` para JSON | Context root real distinto al esperado (`/` en vez de `/poc-jakarta`) |
| Adecuación al proyecto | Buena, ya tiene resuelta la conexión a PostgreSQL y es la tecnología más conocida por el grupo | Buena para performance, pero suma una tecnología nueva | Más pesada de configurar para el tiempo del proyecto |

No se eligió ganador solo por velocidad: Quarkus arrancó más rápido y generó
la imagen más chica, pero **Spring Boot es la única de las tres que ya se
probó conectada de verdad a la base PostgreSQL del proyecto**, y es la
tecnología con la que el grupo tiene más experiencia.

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
- Ninguno de estos problemas se "arregló a lo loco": cada uno está
  documentado acá y en `docs/poc/resultados-backend.md` con la causa y la
  corrección aplicada.

## 11. Qué quedó pendiente

- Conectar Quarkus y Jakarta EE/GlassFish a PostgreSQL real (por ahora solo
  Spring Boot está probado contra la base).
- Probar JPA (no solo JDBC) contra la base real.
- Implementar `POST /reservas` y `PATCH /reservas/{id}/cancelacion` contra
  la base real, respetando el estado `ACTIVA`/`CANCELADA`.
- Implementar `GET /mis-reservas` con `11_reservas_usuario.sql`.
- Definir con el grupo la tecnología final (todo indica que la idea es
  Spring Boot, dado el nombre de la rama y que ya está conectado a la
  base).
- Agregar tests automatizados para los endpoints que ya hablan con la base
  real.
- Sacar capturas de pantalla reales de DBeaver cuando alguien lo pruebe
  desde una máquina con entorno gráfico (acá no fue posible).

## 12. Dónde está cada cosa

- `docs/poc/resultados-backend.md`: informe detallado de la POC de
  backend (fases 1 a 9, antes de conectar la base real).
- `docs/poc/comandos-pruebas-backend.md`: comandos para repetir las pruebas
  REST de cada tecnología.
- `database/poc-sql/`: SQL de referencia del POC de base de datos.
- Este archivo (`TODOELPOC.md`): resumen de todo, incluida la conexión real
  a PostgreSQL.
