package uy.edu.proyecto.backend.auth;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.auth.CuentaAuthRepository.CuentaAutenticacion;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.security.JwtService;
import uy.edu.proyecto.backend.usuario.CiUruguaya;

@Service
public class AuthService {

    private final CuentaAuthRepository cuentaAuthRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final SesionTokenService sesionTokenService;

    public AuthService(
            CuentaAuthRepository cuentaAuthRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            SesionTokenService sesionTokenService
    ) {
        this.cuentaAuthRepository = cuentaAuthRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.sesionTokenService = sesionTokenService;
    }

    @Transactional
    public AuthResult login(LoginRequest request) {
        if (request == null) {
            throw validacion("El cuerpo de la solicitud es obligatorio");
        }

        return loginCuenta(request);
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

        SesionTokenService.Rotado rotado =
                sesionTokenService.rotar(refreshToken);
        CuentaAutenticacion cuenta = cuentaAuthRepository
                .buscarHabilitadaPorId(rotado.idCuenta())
                .orElseThrow(this::credencialesInvalidasModernas);

        return resultadoCuenta(cuenta, rotado.token());
    }

    public void logout(String refreshToken) {
        sesionTokenService.revocar(refreshToken);
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

    private boolean estaVacio(String valor) {
        return valor == null || valor.isBlank();
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
}
