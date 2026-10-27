package uy.edu.proyecto.backend.correo;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

/** Envio por API HTTPS de Resend, apto para Railway. La clave llega por RESEND_API_KEY. */
@Component
@ConditionalOnProperty(name = "app.mail.provider", havingValue = "resend")
public class ResendCorreoSender implements CorreoSender {

    private static final Duration TIMEOUT = Duration.ofSeconds(10);

    private final HttpClient client = HttpClient.newBuilder()
            .connectTimeout(TIMEOUT)
            .build();
    private final ObjectMapper mapper = new ObjectMapper();
    private final String baseUrl;
    private final String apiKey;
    private final String from;

    public ResendCorreoSender(
            @Value("${app.mail.resend.base-url:https://api.resend.com}") String baseUrl,
            @Value("${app.mail.resend.api-key:}") String apiKey,
            @Value("${app.email.from:}") String from
    ) {
        this.baseUrl = baseUrl.endsWith("/")
                ? baseUrl.substring(0, baseUrl.length() - 1)
                : baseUrl;
        this.apiKey = apiKey;
        this.from = from;
    }

    @Override
    public void enviar(CorreoMensaje mensaje) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new CorreoException("Falta RESEND_API_KEY");
        }
        if (from == null || from.isBlank()) {
            throw new CorreoException("Falta MAIL_FROM");
        }

        try {
            String cuerpo = mapper.writeValueAsString(Map.of(
                    "from", from,
                    "to", List.of(mensaje.para()),
                    "subject", mensaje.asunto(),
                    "text", mensaje.texto()
            ));
            HttpRequest request = HttpRequest.newBuilder(URI.create(baseUrl + "/emails"))
                    .timeout(TIMEOUT)
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .header("User-Agent", "proyecto-2026-grupo4-api")
                    .POST(HttpRequest.BodyPublishers.ofString(cuerpo))
                    .build();

            HttpResponse<Void> respuesta = client.send(
                    request,
                    HttpResponse.BodyHandlers.discarding()
            );
            if (respuesta.statusCode() / 100 != 2) {
                throw new CorreoException(
                        "Resend respondio HTTP " + respuesta.statusCode()
                );
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new CorreoException("Envio por Resend interrumpido");
        } catch (IOException | JacksonException exception) {
            throw new CorreoException(
                    "Fallo el envio por Resend: " + exception.getClass().getSimpleName()
            );
        }
    }
}
