# Dockerfile minimo para la POC de Quarkus (fast-jar).
# Build: docker build -t poc-quarkus -f backend/poc-quarkus/Dockerfile backend/poc-quarkus
FROM eclipse-temurin:25-jre
WORKDIR /app
COPY target/quarkus-app/ /app/
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
