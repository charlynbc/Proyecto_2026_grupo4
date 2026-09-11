# Dockerfile minimo para la POC de Spring Boot.
# Build: docker build -t poc-springboot -f backend/poc-springboot/Dockerfile backend/poc-springboot
FROM eclipse-temurin:25-jre
WORKDIR /app
COPY target/poc-backend-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
