# Dockerfile minimo para la POC de Jakarta EE, con GlassFish embebido.
# El contexto de build tiene que ser la raiz del repo, porque necesita el jar
# de tools/glassfish que esta fuera de esta carpeta.
# Build (desde la raiz del repo):
# docker build -t poc-jakarta -f backend/poc-jakarta-glassfish/Dockerfile .
FROM eclipse-temurin:25-jre
WORKDIR /app
COPY backend/poc-jakarta-glassfish/target/poc-jakarta.war poc-jakarta.war
COPY tools/glassfish/glassfish-embedded-all-8.0.4.jar glassfish-embedded-all-8.0.4.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "glassfish-embedded-all-8.0.4.jar", "--httpPort=8082", "poc-jakarta.war"]
