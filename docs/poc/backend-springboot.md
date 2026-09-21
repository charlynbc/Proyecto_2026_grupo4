# POC Backend - Spring Boot

## Objetivo

Evaluar Spring Boot como framework para desarrollar el backend en Java del sistema de reserva de órdenes.

La prueba de concepto busca validar la creación de una API REST, su ejecución local y su posterior conexión con la base de datos PostgreSQL utilizada por el proyecto.

## Tecnologías involucradas

- Java
- Spring Boot
- Maven
- PostgreSQL
- Postman
- Git
- GitHub

## Ambiente de trabajo

- Entorno: GitHub Codespaces
- Sistema operativo: Linux
- Java: OpenJDK 25.0.2 LTS
- Maven: 3.9.13
- Repositorio: Proyecto_2026_grupo4
- Rama: poc/backend-springboot

## Pruebas previstas

1. Crear un proyecto Spring Boot.
2. Ejecutar la aplicación localmente.
3. Crear un endpoint REST básico.
4. Probar el endpoint.
5. Conectar Spring Boot con PostgreSQL.
6. Consultar información de la base de datos mediante la API.

## Resultados

## Prueba 1 - Creación y ejecución del proyecto Spring Boot

Se generó un proyecto utilizando Spring Initializr con Maven, Java y Spring Web.

El proyecto fue compilado y probado correctamente mediante Maven.

Resultado: exitoso.

## Prueba 2 - Creación de endpoint REST básico

Se creó un controlador REST utilizando la anotación `@RestController`.

Se implementó el endpoint:

GET /hola

El endpoint fue probado localmente mediante una petición HTTP y respondió:

POC backend funcionando

Resultado: exitoso.


## Problemas encontrados

## Problemas encontrados

Al acceder inicialmente a la ruta raíz `/`, Spring Boot devolvió un error
HTTP 404 mediante Whitelabel Error Page.

Se comprobó que el servidor funcionaba correctamente y que el error se debía
a que no existía un endpoint asociado a `/`. Al acceder al endpoint `/hola`,
la respuesta fue correcta.

## Conclusión

Pendiente.