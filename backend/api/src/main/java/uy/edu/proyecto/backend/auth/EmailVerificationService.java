package uy.edu.proyecto.backend.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.UsuarioRepository;

@Service
public class EmailVerificationService {

    private static final Duration TOKEN_LIFETIME = Duration.ofHours(24);

    private final UsuarioRepository usuarioRepository;
    private final JavaMailSender mailSender;
    private final SecureRandom secureRandom = new SecureRandom();
    private final String from;
    private final String verificationUrl;

    public EmailVerificationService(
            UsuarioRepository usuarioRepository,
            JavaMailSender mailSender,
            @Value("${app.email.from:}") String from,
            @Value("${app.email.verification-url}") String verificationUrl
    ) {
        this.usuarioRepository = usuarioRepository;
        this.mailSender = mailSender;
        this.from = from;
        this.verificationUrl = verificationUrl;
    }

    public void enviarPara(Long usuarioId, String email) {

        byte[] tokenBytes = new byte[32];
        secureRandom.nextBytes(tokenBytes);

        String token = Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(tokenBytes);

        usuarioRepository.guardarTokenVerificacion(
                usuarioId,
                hash(token),
                Instant.now().plus(TOKEN_LIFETIME)
        );

        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(email);
        if (!from.isBlank()) {
            message.setFrom(from);
        }
        message.setSubject("Confirmación de correo electrónico");
        message.setText(
                "Confirma tu correo electrónico abriendo este enlace:\n\n"
                        + verificationUrl
                        + "?token="
                        + token
                        + "\n\nEl enlace vence en 24 horas."
        );

        mailSender.send(message);
    }

    public void confirmar(String token) {

        if (token == null || token.isBlank()) {
            throw tokenInvalido();
        }

        usuarioRepository
                .consumirTokenVerificacion(hash(token), Instant.now())
                .ifPresentOrElse(
                        usuarioRepository::marcarEmailVerificado,
                        () -> {
                            throw tokenInvalido();
                        }
                );
    }

    private String hash(String token) {

        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8));

            StringBuilder result = new StringBuilder(64);
            for (byte value : digest) {
                result.append(String.format("%02x", value));
            }
            return result.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 no disponible", exception);
        }
    }

    private ApiException tokenInvalido() {

        return new ApiException(
                HttpStatus.BAD_REQUEST,
                "TOKEN_EMAIL_INVALIDO",
                "El enlace de confirmacion no es valido o ya expiro"
        );
    }
}