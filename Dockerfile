# Imagen del sistema en tres etapas: una compila la app Flutter web, otra el
# backend con el JDK y Maven, y la final solo lleva el JRE, el JAR y los
# archivos de la web. Así la imagen que se despliega no incluye Flutter, el
# compilador, Maven ni el código fuente.
#
# La web y la API se sirven desde el mismo origen (Arquitectura, DA-11): las
# cookies de la sesión son de primera parte y funcionan también en Safari.

# --- Etapa 1: app Flutter web -----------------------------------------------
FROM debian:bookworm-slim AS web
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

# La misma versión que usa el CI del frontend (frontend.yml). Se instala desde
# el repositorio oficial porque no hay imagen de Docker mantenida de esta versión.
RUN git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --enable-web > /dev/null \
 && flutter precache --web

WORKDIR /web
# Igual que con Maven: mientras pubspec no cambie, Docker reutiliza esta capa.
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get

COPY frontend/ ./
# API_BASE_URL vacío: la app llama a /api/... en el mismo dominio que la sirve.
RUN flutter build web --release --dart-define=API_BASE_URL=

# --- Etapa 2: compilación del backend ---------------------------------------
FROM eclipse-temurin:25-jdk AS build
WORKDIR /build

# Primero solo lo que define las dependencias: mientras pom.xml no cambie,
# Docker reutiliza esta capa y no vuelve a descargar todo en cada build.
COPY backend/api/.mvn/ .mvn/
COPY backend/api/mvnw backend/api/pom.xml ./
RUN ./mvnw -B -q dependency:go-offline

COPY backend/api/src/ src/
# Las pruebas corren en el CI (workflow Backend), no al construir la imagen:
# necesitan una base de datos que acá no hay.
RUN ./mvnw -B -q -DskipTests package \
 && cp target/api-*.jar app.jar

# --- Etapa 3: ejecución -----------------------------------------------------
FROM eclipse-temurin:25-jre
WORKDIR /app

# El proceso no corre como root dentro del contenedor.
RUN useradd --system --uid 10001 --no-create-home app
COPY --from=build /build/app.jar app.jar
COPY --from=web /web/build/web/ static/
USER app

EXPOSE 8080
# La JVM usa como máximo el 75 % de la memoria que la plataforma asigna al contenedor.
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75"
# Spring Boot sirve la app web desde esta carpeta; "/" muestra su index.html.
ENV SPRING_WEB_RESOURCES_STATIC_LOCATIONS="file:/app/static/"
# Railway indica el puerto en la variable PORT; en local se usa 8080.
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -Dserver.port=${PORT:-8080} -jar /app/app.jar"]
