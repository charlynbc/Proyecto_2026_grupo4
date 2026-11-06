package uy.edu.proyecto.backend.security;

import java.time.Instant;

import org.springframework.beans.factory.annotation.Value;

import org.springframework.security.oauth2.jose.jws.MacAlgorithm;

import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;

import org.springframework.stereotype.Service;

@Service
public class JwtService {

    private final JwtEncoder jwtEncoder;
    private final long expirationSeconds;


    public JwtService(
            JwtEncoder jwtEncoder,

            @Value(
                "${app.jwt.expiration-seconds}"
            )
            long expirationSeconds
    ) {
        this.jwtEncoder = jwtEncoder;
        this.expirationSeconds =
                expirationSeconds;
    }


    public String generar(
            Long usuarioId,
            String rol
    ) {

        Instant ahora =
                Instant.now();

        JwtClaimsSet claims =
                JwtClaimsSet
                        .builder()

                        .issuer(
                                "grupo4-api"
                        )

                        .subject(
                                usuarioId.toString()
                        )

                        .claim(
                                "role",
                                rol
                        )

                        // Precision completa para invalidar JWT anteriores a
                        // una reactivacion incluso dentro del mismo segundo.
                        .claim("issued_at_precise", ahora.toString())

                        .issuedAt(ahora)

                        .expiresAt(
                                ahora.plusSeconds(
                                        expirationSeconds
                                )
                        )

                        .build();


        JwsHeader header =
                JwsHeader
                        .with(
                                MacAlgorithm.HS256
                        )
                        .build();


        return jwtEncoder
                .encode(
                        JwtEncoderParameters
                                .from(
                                        header,
                                        claims
                                )
                )
                .getTokenValue();
    }


    public long getExpirationSeconds() {
        return expirationSeconds;
    }
}
