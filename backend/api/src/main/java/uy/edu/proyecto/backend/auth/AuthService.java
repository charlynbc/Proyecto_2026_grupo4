package uy.edu.proyecto.backend.auth;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.auth.CuentaAuthRepository.CuentaAutenticacion;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.security.JwtService;
import uy.edu.proyecto.backend.usuario.CiUruguaya;
import uy.edu.proyecto.backend.usuario.UsuarioCredenciales;
import uy.edu.proyecto.backend.usuario.UsuarioRepository;

@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final CuentaAuthRepository cuentaAuthRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final SesionTokenService sesionTokenService;

    public AuthService(
            UsuarioRepository usuarioRepository,
            CuentaAuthRepository cuentaAuthRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            RefreshTokenService refreshTokenService,
            SesionTokenService sesionTokenService
    ) {
        this.usuarioRepository = usuarioRepository;
        this.cuentaAuthRepository = cuentaAuthRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.sesionTokenService = sesionTokenService;
    }

    @Transactional
    public AuthResult login(LoginRequest request) {
        if (request == null) {
            throw validacion("El cuerpo de la solicitud es obligatorio");
        }

        if (esContratoNuevo(request)) {
            return loginCuenta(request);
        }
        return loginLegado(request);
    }

    @Transactional
    public AuthResult refresh(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "REFRESH_FALTANTE",
                    "La sesion no es valida"
            );
        }

        if (sesionTokenService.reconoceToken(refreshToken)) {
            SesionTokenService.Rotado rotado =
                    sesionTokenService.rotar(refreshToken);
            CuentaAutenticacion cuenta = cuentaAuthRepository
                    .buscarHabilitadaPorId(rotado.idCuenta())
                    .orElseThrow(this::credencialesInvalidasModernas);

            return resultadoCuenta(cuenta, rotado.token());
        }

        RefreshTokenService.Rotado rotado =
                refreshTokenService.rotar(refreshToken);
        UsuarioCredenciales usuario =
                usuarioRepository.buscarPorId(rotado.usuarioId())
                        .orElseThrow(() -> new ApiException(
                                HttpStatus.UNAUTHORIZED,
                                "SESION_INVALIDA",
                                "La sesion no es valida"
                        ));

        String accessToken = jwtService.generar(usuario.id(), usuario.rol());
        return new AuthResult(
                new LoginResponse(
                        accessToken,
                        "Bearer",
                        jwtService.getExpirationSeconds(),
                        usuario.rol(),
                        null,
                        null
                ),
                rotado.token()
        );
    }

    public void logout(String refreshToken) {
        if (sesionTokenService.reconoceToken(refreshToken)) {
            sesionTokenService.revocar(refreshToken);
            return;
        }
        refreshTokenService.revocar(refreshToken);
    }

    private AuthResult loginCuenta(LoginRequest request) {
        if (estaVacio(request.ci())
                || estaVacio(request.password())
                || estaVacio(request.acceso())) {
            throw validacion("Falta un campo obligatorio");
        }

        String acceso = request.acceso().trim();
        if (!acceso.equals("SOCIO") && !acceso.equals("EMPLEADO")) {
            throw validacion("El acceso debe ser SOCIO o EMPLEADO");
        }

        String plataforma = request.plataforma() == null
                ? null
                : request.plataforma().trim();
        if (plataforma != null
                && !plataforma.equals("WEB")
                && !plataforma.equals("ANDROID")) {
            throw validacion("La plataforma debe ser WEB o ANDROID");
        }
        if (acceso.equals("EMPLEADO") && estaVacio(plataforma)) {
            throw validacion("La plataforma es obligatoria para acceso EMPLEADO");
        }
        if (acceso.equals("EMPLEADO") && !plataforma.equals("WEB")) {
            throw credencialesInvalidasModernas();
        }

        String ci = CiUruguaya.normalizarValida(request.ci())
                .orElseThrow(this::credencialesInvalidasModernas);
        CuentaAutenticacion cuenta = cuentaAuthRepository
                .buscarParaLogin(ci, acceso)
                .orElseThrow(this::credencialesInvalidasModernas);

        if (cuenta.passwordHash() == null
                || !passwordEncoder.matches(
                        request.password(),
                        cuenta.passwordHash()
                )) {
            throw credencialesInvalidasModernas();
        }

        SesionTokenService.Emitido refresh =
                sesionTokenService.emitir(cuenta.id());
        return resultadoCuenta(cuenta, refresh.token());
    }

    private AuthResult loginLegado(LoginRequest request) {
        if (estaVacio(request.cedula()) || estaVacio(request.clave())) {
            throw validacion("Falta un campo obligatorio");
        }

        String cedula = normalizarCedula(request.cedula());
        UsuarioCredenciales usuario = usuarioRepository
                .buscarParaLogin(cedula)
                .orElseThrow(this::credencialesInvalidas);

        if (usuario.passwordHash() == null
                || !passwordEncoder.matches(
                        request.clave(),
                        usuario.passwordHash()
                )) {
            throw credencialesInvalidas();
        }
        if (!usuario.emailVerificado()) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "EMAIL_NO_CONFIRMADO",
                    "Debe confirmar su email antes de iniciar sesion"
            );
        }

        String accessToken = jwtService.generar(usuario.id(), usuario.rol());
        RefreshTokenService.Emitido refresh =
                refreshTokenService.emitir(usuario.id());

        return new AuthResult(
                new LoginResponse(
                        accessToken,
                        "Bearer",
                        jwtService.getExpirationSeconds(),
                        usuario.rol(),
                        null,
                        null
                ),
                refresh.token()
        );
    }

    private AuthResult resultadoCuenta(
            CuentaAutenticacion cuenta,
            String refreshToken
    ) {
        String accessToken = jwtService.generar(cuenta.id(), cuenta.rol());
        return new AuthResult(
                new LoginResponse(
                        accessToken,
                        "Bearer",
                        jwtService.getExpirationSeconds(),
                        cuenta.rol(),
                        cuenta.nombre(),
                        cuenta.apellido()
                ),
                refreshToken
        );
    }

    private boolean esContratoNuevo(LoginRequest request) {
        return request.ci() != null
                || request.password() != null
                || request.acceso() != null
                || request.plataforma() != null;
    }

    private boolean estaVacio(String valor) {
        return valor == null || valor.isBlank();
    }

    private ApiException credencialesInvalidas() {
        return new ApiException(
                HttpStatus.UNAUTHORIZED,
                "CREDENCIALES_INVALIDAS",
                "Credenciales incorrectas"
        );
    }

    private ApiException credencialesInvalidasModernas() {
        return new ApiException(
                HttpStatus.UNAUTHORIZED,
                "CREDENCIALES_INVALIDAS",
                "La cedula o la contrasena no son correctas. Revisa los datos e intenta de nuevo."
        );
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(
                HttpStatus.BAD_REQUEST,
                "VALIDACION",
                mensaje
        );
    }

    private String normalizarCedula(String cedula) {
        return cedula.replaceAll("[.\\-\\s]", "");
    }
}
