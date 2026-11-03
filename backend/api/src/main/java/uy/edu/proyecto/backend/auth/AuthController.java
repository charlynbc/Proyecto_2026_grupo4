package uy.edu.proyecto.backend.auth;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    private final CambioContrasenaService cambioContrasenaService;

    private final RefreshCookieService
            refreshCookieService;


    public AuthController(
            AuthService authService,
            CambioContrasenaService cambioContrasenaService,
            RefreshCookieService refreshCookieService
    ) {
        this.authService = authService;

        this.cambioContrasenaService =
                cambioContrasenaService;

        this.refreshCookieService =
                refreshCookieService;
    }


    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(
            @RequestBody
            LoginRequest request
    ) {

        AuthResult resultado =
                authService.login(
                        request
                );

        return ResponseEntity
                .ok()
                .header(
                        HttpHeaders.SET_COOKIE,

                        refreshCookieService
                                .crear(
                                        resultado
                                                .refreshToken()
                                )
                                .toString()
                )
                .body(
                        resultado.response()
                );
    }


    @PostMapping("/refresh")
    public ResponseEntity<LoginResponse> refresh(

            @CookieValue(
                    name = "refresh_token",
                    required = false
            )
            String refreshToken
    ) {

        AuthResult resultado =
                authService.refresh(
                        refreshToken
                );

        return ResponseEntity
                .ok()
                .header(
                        HttpHeaders.SET_COOKIE,

                        refreshCookieService
                                .crear(
                                        resultado
                                                .refreshToken()
                                )
                                .toString()
                )
                .body(
                        resultado.response()
                );
    }


    @PostMapping("/logout")
    public ResponseEntity<Void> logout(

            @CookieValue(
                    name = "refresh_token",
                    required = false
            )
            String refreshToken
    ) {

        authService.logout(
                refreshToken
        );

        return ResponseEntity
                .noContent()
                .header(
                        HttpHeaders.SET_COOKIE,

                        refreshCookieService
                                .borrar()
                                .toString()
                )
                .build();
    }


    @PostMapping("/cambiar-contrasena")
    public ResponseEntity<Void> cambiarContrasena(
            @RequestBody
            CambiarContrasenaRequest request,

            @AuthenticationPrincipal
            Jwt jwt,

            @CookieValue(
                    name = "refresh_token",
                    required = false
            )
            String refreshToken
    ) {

        cambioContrasenaService.cambiar(
                idCuenta(jwt),
                request,
                refreshToken
        );

        return ResponseEntity
                .noContent()
                .build();
    }


    private static Long idCuenta(Jwt jwt) {
        try {
            return Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
    }
}
