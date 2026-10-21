# Imagen del backend en dos etapas: una compila con el JDK y Maven, y la final
# solo lleva el JRE y el JAR. Así la imagen que se despliega no incluye el
# compilador, Maven ni el código fuente.

# --- Etapa 1: compilación ---------------------------------------------------
FROM eclipse-temurin:25-jdk AS build
WORKDIR /build

# Primero solo lo que define las dependencias: mientras pom.xml no cambie,
# Docker reutiliza esta capa y no vuelve a descargar todo en cada build.
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN ./mvnw -B -q dependency:go-offline

COPY src/ src/
# Las pruebas corren en el CI (workflow Backend), no al construir la imagen:
# necesitan una base de datos que acá no hay.
RUN ./mvnw -B -q -DskipTests package \
 && cp target/api-*.jar app.jar

# --- Etapa 2: ejecución -----------------------------------------------------
FROM eclipse-temurin:25-jre
WORKDIR /app

# El proceso no corre como root dentro del contenedor.
RUN useradd --system --uid 10001 --no-create-home app
COPY --from=build /build/app.jar app.jar
USER app

EXPOSE 8080
# La JVM usa como máximo el 75 % de la memoria que la plataforma asigna al contenedor.
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75"
# Railway indica el puerto en la variable PORT; en local se usa 8080.
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -Dserver.port=${PORT:-8080} -jar /app/app.jar"]
