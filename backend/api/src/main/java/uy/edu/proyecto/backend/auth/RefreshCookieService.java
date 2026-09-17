package uy.edu.proyecto.backend.auth;

import java.time.Duration;

import org.springframework.beans.factory.annotation.Value;

import org.springframework.http.ResponseCookie;

import org.springframework.stereotype.Service;

@Service
public class RefreshCookieService {

    private final boolean secure;
    private final String sameSite;
    private final long expirationSeconds;


    public RefreshCookieService(

            @Value("${app.cookie.secure}")
            boolean secure,

            @Value("${app.cookie.same-site}")
            String sameSite,

            @Value(
                "${app.refresh.expiration-seconds}"
            )
            long expirationSeconds
    ) {
        this.secure = secure;
        this.sameSite = sameSite;
        this.expirationSeconds =
                expirationSeconds;
    }


    public ResponseCookie crear(
            String token
    ) {

        return ResponseCookie
                .from(
                        "refresh_token",
                        token
                )
                .httpOnly(true)
                .secure(secure)
                .sameSite(sameSite)
                .path("/api/auth")
                .maxAge(
                        Duration.ofSeconds(
                                expirationSeconds
                        )
                )
                .build();
    }


    public ResponseCookie borrar() {

        return ResponseCookie
                .from(
                        "refresh_token",
                        ""
                )
                .httpOnly(true)
                .secure(secure)
                .sameSite(sameSite)
                .path("/api/auth")
                .maxAge(Duration.ZERO)
                .build();
    }
}
