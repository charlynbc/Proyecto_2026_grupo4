package uy.edu.proyecto.backend.auth;

import jakarta.validation.Valid;

import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    private final RefreshCookieService
            refreshCookieService;


    public AuthController(
            AuthService authService,
            RefreshCookieService refreshCookieService
    ) {
        this.authService = authService;

        this.refreshCookieService =
                refreshCookieService;
    }


    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(
            @Valid
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
}
