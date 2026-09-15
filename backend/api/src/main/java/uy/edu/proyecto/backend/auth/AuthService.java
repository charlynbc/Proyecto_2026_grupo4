package uy.edu.proyecto.backend.auth;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.security.JwtService;
import uy.edu.proyecto.backend.usuario.UsuarioCredenciales;
import uy.edu.proyecto.backend.usuario.UsuarioRepository;

@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(
            UsuarioRepository usuarioRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService
    ) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    public LoginResponse login(LoginRequest request) {

        String cedula = normalizarCedula(
                request.cedula()
        );

        UsuarioCredenciales usuario =
                usuarioRepository
                        .buscarParaLogin(cedula)
                        .orElseThrow(
                                this::credencialesInvalidas
                        );

        boolean coincide = passwordEncoder.matches(
                request.clave(),
                usuario.passwordHash()
        );

        if (!coincide) {
            throw credencialesInvalidas();
        }

        String token = jwtService.generar(
                usuario.id()
        );

        return new LoginResponse(
                token,
                "Bearer",
                jwtService.getExpirationSeconds()
        );
    }

    private ApiException credencialesInvalidas() {
        return new ApiException(
                HttpStatus.UNAUTHORIZED,
                "Credenciales incorrectas"
        );
    }

    private String normalizarCedula(String cedula) {
        return cedula.replaceAll("[.\\-\\s]", "");
    }
}
