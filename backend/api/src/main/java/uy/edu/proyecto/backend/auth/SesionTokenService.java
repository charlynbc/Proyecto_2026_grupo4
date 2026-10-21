package uy.edu.proyecto.backend.auth;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Base64;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class SesionTokenService {

    private static final String PREFIJO = "v2.";

    private final SesionRepository repository;
    private final long expirationSeconds;
    private final SecureRandom secureRandom = new SecureRandom();

    public SesionTokenService(
            SesionRepository repository,
            @Value("${app.refresh.expiration-seconds}") long expirationSeconds
    ) {
        this.repository = repository;
        this.expirationSeconds = expirationSeconds;
    }

    public boolean reconoceToken(String token) {
        return token != null && token.startsWith(PREFIJO);
    }

    @Transactional
    public Emitido emitir(Long idCuenta) {
        String token = generarToken();
        repository.crear(idCuenta, hash(token), nuevaExpiracion());
        return new Emitido(token, expirationSeconds);
    }

    @Transactional
    public Rotado rotar(String tokenAnterior) {
        if (tokenAnterior == null || !tokenAnterior.startsWith(PREFIJO)) {
            throw sesionInvalida();
        }

        String tokenNuevo = generarToken();
        Long idCuenta = repository.rotar(
                        hash(tokenAnterior),
                        hash(tokenNuevo),
                        nuevaExpiracion()
                )
                .orElseThrow(this::sesionInvalida);

        return new Rotado(idCuenta, tokenNuevo);
    }

    @Transactional
    public void revocar(String token) {
        if (token != null && token.startsWith(PREFIJO)) {
            repository.revocar(hash(token));
        }
    }

    private String generarToken() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return PREFIJO + Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(bytes);
    }

    private OffsetDateTime nuevaExpiracion() {
        return OffsetDateTime.now(ZoneOffset.UTC)
                .plusSeconds(expirationSeconds);
    }

    private String hash(String token) {
        return TokenHash.sha256(token);
    }

    private ApiException sesionInvalida() {
        return new ApiException(
                HttpStatus.UNAUTHORIZED,
                "REFRESH_INVALIDO",
                "La sesion no es valida"
        );
    }

    public record Emitido(String token, long expiresIn) {
    }

    public record Rotado(Long idCuenta, String token) {
    }
}
