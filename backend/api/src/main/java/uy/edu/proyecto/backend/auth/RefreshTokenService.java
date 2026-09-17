package uy.edu.proyecto.backend.auth;

import java.nio.charset.StandardCharsets;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;

import java.util.Base64;
import java.util.HexFormat;

import org.springframework.beans.factory.annotation.Value;

import org.springframework.http.HttpStatus;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class RefreshTokenService {

    private final RefreshTokenRepository repository;
    private final long expirationSeconds;

    private final SecureRandom secureRandom =
            new SecureRandom();


    public RefreshTokenService(
            RefreshTokenRepository repository,

            @Value(
                "${app.refresh.expiration-seconds}"
            )
            long expirationSeconds
    ) {
        this.repository = repository;
        this.expirationSeconds =
                expirationSeconds;
    }


    @Transactional
    public Emitido emitir(
            Long usuarioId
    ) {

        String token =
                generarToken();

        repository.crear(
                usuarioId,
                hash(token),
                nuevaExpiracion()
        );

        return new Emitido(
                token,
                expirationSeconds
        );
    }


    @Transactional
    public Rotado rotar(
            String tokenAnterior
    ) {

        String tokenNuevo =
                generarToken();

        Long usuarioId =
                repository
                        .rotar(
                                hash(tokenAnterior),
                                hash(tokenNuevo),
                                nuevaExpiracion()
                        )
                        .orElseThrow(
                                () ->
                                        new ApiException(
                                                HttpStatus.UNAUTHORIZED,
                                                "REFRESH_INVALIDO",
                                                "La sesion no es valida"
                                        )
                        );

        return new Rotado(
                usuarioId,
                tokenNuevo,
                expirationSeconds
        );
    }


    public void revocar(
            String token
    ) {

        if (
            token == null
            || token.isBlank()
        ) {
            return;
        }

        repository.revocar(
                hash(token)
        );
    }


    private String generarToken() {

        byte[] bytes =
                new byte[32];

        secureRandom.nextBytes(bytes);

        return Base64
                .getUrlEncoder()
                .withoutPadding()
                .encodeToString(bytes);
    }


    private OffsetDateTime nuevaExpiracion() {

        return OffsetDateTime
                .now(ZoneOffset.UTC)
                .plusSeconds(
                        expirationSeconds
                );
    }


    private String hash(
            String token
    ) {

        try {

            MessageDigest digest =
                    MessageDigest
                            .getInstance(
                                    "SHA-256"
                            );

            byte[] bytes =
                    digest.digest(
                            token.getBytes(
                                    StandardCharsets.UTF_8
                            )
                    );

            return HexFormat
                    .of()
                    .formatHex(bytes);

        } catch (
            NoSuchAlgorithmException exception
        ) {

            throw new IllegalStateException(
                    exception
            );
        }
    }


    public record Emitido(
            String token,
            long expiresIn
    ) {
    }


    public record Rotado(
            Long usuarioId,
            String token,
            long expiresIn
    ) {
    }
}
