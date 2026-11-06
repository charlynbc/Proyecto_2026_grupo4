package uy.edu.proyecto.backend.anuncio;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;
import uy.edu.proyecto.backend.exception.ApiException;

/** Acceso a Storage solo desde el servidor; la clave nunca se entrega a Flutter. */
@Component
public class SupabaseAlmacenImagenes implements AlmacenImagenes {
    private static final Duration TIMEOUT = Duration.ofSeconds(20);
    private final HttpClient client = HttpClient.newBuilder().connectTimeout(TIMEOUT).build();
    private final ObjectMapper mapper = new ObjectMapper();
    private final String base;
    private final String key;
    private final String bucket;

    public SupabaseAlmacenImagenes(
            @Value("${app.anuncios.storage.url:}") String url,
            @Value("${app.anuncios.storage.key:}") String key,
            @Value("${app.anuncios.storage.bucket:anuncios}") String bucket) {
        this.base = url.replaceAll("/+$", "");
        this.key = key;
        this.bucket = bucket;
    }

    @Override
    public void guardar(String referencia, byte[] contenido, String tipo) {
        enviar("POST", "/object/" + bucket + "/" + referencia,
                HttpRequest.BodyPublishers.ofByteArray(contenido), tipo);
    }

    @Override
    public String enlaceTemporal(String referencia) {
        String respuesta = enviar("POST", "/object/sign/" + bucket + "/" + referencia,
                HttpRequest.BodyPublishers.ofString("{\"expiresIn\":3600}"), "application/json");
        try {
            String ruta = mapper.readTree(respuesta).path("signedURL").asText();
            if (!ruta.startsWith("/object/sign/")) throw almacenamiento();
            return base + "/storage/v1" + ruta;
        } catch (RuntimeException error) {
            throw almacenamiento();
        }
    }

    @Override
    public void borrar(String referencia) {
        enviar("DELETE", "/object/" + bucket + "/" + referencia,
                HttpRequest.BodyPublishers.noBody(), null);
    }

    private String enviar(String metodo, String ruta, HttpRequest.BodyPublisher cuerpo, String tipo) {
        if (base.isBlank() || key == null || key.isBlank()) throw almacenamiento();
        var builder = HttpRequest.newBuilder(URI.create(base + "/storage/v1" + ruta))
                .timeout(TIMEOUT)
                .header("apikey", key)
                .header("Authorization", "Bearer " + key);
        if (tipo != null) builder.header("Content-Type", tipo);
        try {
            var respuesta = client.send(builder.method(metodo, cuerpo).build(),
                    HttpResponse.BodyHandlers.ofString());
            if (respuesta.statusCode() / 100 != 2) throw almacenamiento();
            return respuesta.body();
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            throw almacenamiento();
        } catch (IOException error) {
            throw almacenamiento();
        }
    }

    private static ApiException almacenamiento() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                "ALMACENAMIENTO_NO_DISPONIBLE", "No se pudo acceder a las imágenes");
    }
}
