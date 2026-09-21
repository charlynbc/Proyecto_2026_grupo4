Spring Boot
Estructura y gestiona un proyecto backend Java.

pom.xml
Configuración de Maven. Ahí están las dependencias del proyecto.

src/main/java
Codigo Java.

src/main/resources
Configuraciones, por ejemplo application.properties.

src/test
Pruebas.

mvnw
Maven Wrapper. Permite que el proyecto use una versión adecuada de Maven sin depender tanto de lo instalado en cada PC

ARQUITECTURA
Cliente
  ↓
GET /hola
  ↓
HolaController
  ↓
"POC backend funcionando"