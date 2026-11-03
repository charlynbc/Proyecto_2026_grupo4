# Comandos de prueba - POC Backend

Estos son los comandos reales que se usaron para probar los tres backends.
Sirven para que cualquiera del grupo pueda repetir las pruebas en su propia
máquina o Codespace.

Requisitos previos:

- Java 25 instalado.
- Maven instalado (o usar los wrappers `mvnw` de cada proyecto).
- No hace falta PostgreSQL para estas pruebas, no se usa base de datos real.

## 1. Spring Boot (puerto 8080)

```bash
cd backend/poc-springboot

# Correr los tests
./mvnw test

# Generar el jar
./mvnw package

# Levantar la aplicación
java -jar target/poc-backend-0.0.1-SNAPSHOT.jar
```

En otra terminal, probar el endpoint:

```bash
curl -s -o /tmp/spring_body.txt -w "HTTP_CODE:%{http_code} TIME:%{time_total}\n" http://localhost:8080/hola
cat /tmp/spring_body.txt
```

Resultado esperado: `HTTP_CODE:200` y cuerpo `POC backend funcionando`.

> Nota: si aparece un error de `Failed to determine a suitable driver class`,
> es porque el `pom.xml` trae `spring-boot-starter-data-jpa` + `postgresql`
> pero no hay ningún datasource configurado. Ya se agregó la propiedad
> `spring.autoconfigure.exclude` en `application.properties` (main y test)
> para evitar este problema mientras no conectemos una base real.

Con la app levantada, también se puede probar (todo mock, sin base real):

```bash
# Listado de profesionales (mock)
curl -s http://localhost:8080/profesionales

# Horarios de un profesional (mock)
curl -s http://localhost:8080/profesionales/1/horarios

# Reservar un horario
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"usuarioId":1,"horarioId":101}' http://localhost:8080/reservas

# Intentar reservar el mismo horario de nuevo (debe dar 409)
curl -s -w "\nHTTP:%{http_code}\n" -X POST -H "Content-Type: application/json" \
  -d '{"usuarioId":2,"horarioId":101}' http://localhost:8080/reservas
```

## 2. Quarkus (puerto 8081)

```bash
cd backend/poc-quarkus

# Compilar
mvn compile

# Empaquetar
mvn package

# Levantar la aplicación (fast-jar)
java -jar target/quarkus-app/quarkus-run.jar
```

En otra terminal:

```bash
curl -s -o /tmp/quarkus_body.txt -w "HTTP_CODE:%{http_code} TIME:%{time_total}\n" http://localhost:8081/hola
cat /tmp/quarkus_body.txt
```

Resultado esperado: `HTTP_CODE:200` y cuerpo `POC Quarkus funcionando`.

> Nota: el proyecto no tenía `pom.xml` cuando se hizo esta prueba. Se agregó
> uno mínimo con el BOM de Quarkus 3.17.5 y las dependencias `quarkus-resteasy`
> + `quarkus-resteasy-jackson` (esta última para poder devolver JSON) para
> poder compilar el código que ya existía.

Profesionales (mock):

```bash
curl -s http://localhost:8081/profesionales
```

## 3. Jakarta EE / GlassFish (puerto 8082)

```bash
bash scripts/run-glassfish.sh
```

Este script hace `mvn package` dentro de `backend/poc-jakarta-glassfish` y
después levanta GlassFish embebido con el WAR generado
(`target/poc-jakarta.war`) en el puerto 8082.

En otra terminal, probar el endpoint (la ruta real es distinta a la que uno
podría suponer por el nombre del WAR):

```bash
curl -s -o /tmp/gf_body.txt -w "HTTP_CODE:%{http_code} TIME:%{time_total}\n" http://localhost:8082/api/hola
cat /tmp/gf_body.txt
```

Resultado esperado: `HTTP_CODE:200` y cuerpo
`POC Jakarta EE / GlassFish funcionando`.

> Nota: `GET /poc-jakarta/api/hola` devuelve `404`. GlassFish embebido, con la
> configuración actual, despliega el WAR en el context root `/`, no en
> `/poc-jakarta`. La ruta correcta es `/api/hola`, que sale de combinar
> `@ApplicationPath("/api")` (en `RestApplication.java`) con `@Path("/hola")`
> (en `HolaResource.java`).

Profesionales (mock):

```bash
curl -s http://localhost:8082/api/profesionales
```

## 4. Docker (las tres tecnologías)

Requiere Docker corriendo en el Codespace (`docker ps` para comprobarlo).

```bash
# Spring Boot: primero generar el jar (./mvnw package dentro de backend/poc-springboot)
docker build -t poc-springboot -f backend/poc-springboot/Dockerfile backend/poc-springboot
docker run -d --name poc-springboot-run -p 8080:8080 poc-springboot
curl -s -w "\nHTTP:%{http_code}\n" http://localhost:8080/hola
docker rm -f poc-springboot-run

# Quarkus: primero generar target/quarkus-app (mvn package dentro de backend/poc-quarkus)
docker build -t poc-quarkus -f backend/poc-quarkus/Dockerfile backend/poc-quarkus
docker run -d --name poc-quarkus-run -p 8081:8081 poc-quarkus
curl -s -w "\nHTTP:%{http_code}\n" http://localhost:8081/hola
docker rm -f poc-quarkus-run

# Jakarta EE / GlassFish: primero generar el WAR (mvn package dentro de backend/poc-jakarta-glassfish)
# OJO: este build se corre desde la RAIZ del repo porque necesita el jar de tools/glassfish
docker build -t poc-jakarta -f backend/poc-jakarta-glassfish/Dockerfile .
docker run -d --name poc-jakarta-run -p 8082:8082 poc-jakarta
curl -s -w "\nHTTP:%{http_code}\n" http://localhost:8082/api/hola
docker rm -f poc-jakarta-run
```

> Nota: los tres `Dockerfile` usan `eclipse-temurin:25-jre` porque los tres
> proyectos compilan con Java 25. Con `21-jre` los contenedores fallan con
> `UnsupportedClassVersionError`.

## Detener los procesos

Cada uno de los tres backends queda corriendo en primer plano en la terminal
donde se ejecutó `java -jar ...` o el script de GlassFish. Para detenerlos
alcanza con `Ctrl+C` en esa terminal.
