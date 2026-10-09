package uy.edu.proyecto.backend.auth;

import org.springframework.http.HttpStatus;

import org.springframework.security.crypto.password.PasswordEncoder;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

import uy.edu.proyecto.backend.security.JwtService;

import uy.edu.proyecto.backend.usuario.UsuarioCredenciales;
import uy.edu.proyecto.backend.usuario.UsuarioRepository;

@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;

    private final PasswordEncoder passwordEncoder;

    private final JwtService jwtService;

    private final RefreshTokenService
            refreshTokenService;


    public AuthService(
            UsuarioRepository usuarioRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            RefreshTokenService refreshTokenService
    ) {
        this.usuarioRepository =
                usuarioRepository;

        this.passwordEncoder =
                passwordEncoder;

        this.jwtService =
                jwtService;

        this.refreshTokenService =
                refreshTokenService;
    }


    @Transactional
    public AuthResult login(
            LoginRequest request
    ) {

        String cedula =
                normalizarCedula(
                        request.cedula()
                );


        UsuarioCredenciales usuario =
                usuarioRepository
                        .buscarParaLogin(
                                cedula
                        )
                        .orElseThrow(
                                this::credencialesInvalidas
                        );


        if (
            !passwordEncoder.matches(
                    request.clave(),
                    usuario.passwordHash()
            )
        ) {

            throw credencialesInvalidas();
        }

                if (!usuario.emailVerificado()) {
                        throw new ApiException(
                                        HttpStatus.FORBIDDEN,
                                        "EMAIL_NO_CONFIRMADO",
                                        "Debe confirmar su email antes de iniciar sesion"
                        );
                }


        String accessToken =
                jwtService.generar(
                        usuario.id(),
                        usuario.rol()
                );


        RefreshTokenService.Emitido refresh =
                refreshTokenService.emitir(
                        usuario.id()
                );


        LoginResponse response =
                new LoginResponse(
                        accessToken,
                        "Bearer",
                        jwtService
                                .getExpirationSeconds(),
                        usuario.rol()
                );


        return new AuthResult(
                response,
                refresh.token()
        );
    }


    @Transactional
    public AuthResult refresh(
            String refreshToken
    ) {

        if (
            refreshToken == null
            || refreshToken.isBlank()
        ) {

            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "REFRESH_FALTANTE",
                    "La sesion no es valida"
            );
        }


        RefreshTokenService.Rotado rotado =
                refreshTokenService
                        .rotar(
                                refreshToken
                        );


        UsuarioCredenciales usuario =
                usuarioRepository
                        .buscarPorId(
                                rotado.usuarioId()
                        )
                        .orElseThrow(
                                () ->
                                        new ApiException(
                                                HttpStatus.UNAUTHORIZED,
                                                "SESION_INVALIDA",
                                                "La sesion no es valida"
                                        )
                        );


        String accessToken =
                jwtService.generar(
                        usuario.id(),
                        usuario.rol()
                );


        return new AuthResult(

                new LoginResponse(
                        accessToken,
                        "Bearer",
                        jwtService
                                .getExpirationSeconds(),
                        usuario.rol()
                ),

                rotado.token()
        );
    }


    public void logout(
            String refreshToken
    ) {

        refreshTokenService
                .revocar(
                        refreshToken
                );
    }


    private ApiException
    credencialesInvalidas() {

        return new ApiException(
                HttpStatus.UNAUTHORIZED,
                "CREDENCIALES_INVALIDAS",
                "Credenciales incorrectas"
        );
    }


    private String normalizarCedula(
            String cedula
    ) {

        return cedula.replaceAll(
                "[.\\-\\s]",
                ""
        );
    }
}
