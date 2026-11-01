package uy.edu.proyecto.backend.auth;

import java.nio.charset.StandardCharsets;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

/**
 * RF-04: cambio de contrasena del usuario autenticado. La identidad sale del JWT
 * (nunca del cliente), se verifica la contrasena actual y la nueva se guarda con
 * el mismo BCrypt del resto del sistema. El bloqueo de la fila (FOR UPDATE)
 * serializa cambios concurrentes sobre la misma cuenta. Al completarse, se
 * revocan las demas sesiones de la cuenta; la sesion actual sobrevive.
 */
@Service
public class CambioContrasenaService {

    private static final int MAX_BCRYPT_PASSWORD_BYTES = 72;

    private final CuentaAuthRepository cuentaRepository;
    private final SesionRepository sesionRepository;
    private final PasswordEncoder passwordEncoder;
    private final int minimumPasswordLength;

    public CambioContrasenaService(
            CuentaAuthRepository cuentaRepository,
            SesionRepository sesionRepository,
            PasswordEncoder passwordEncoder,
            @Value("${app.auth.password-min-length:8}") int minimumPasswordLength
    ) {
        this.cuentaRepository = cuentaRepository;
        this.sesionRepository = sesionRepository;
        this.passwordEncoder = passwordEncoder;
        this.minimumPasswordLength = minimumPasswordLength;
    }

    @Transactional
    public void cambiar(
            Long idCuenta,
            CambiarContrasenaRequest request,
            String refreshTokenActual
    ) {
        validar(request);

        // FOR UPDATE: dos cambios simultaneos de la misma cuenta se serializan;
        // el segundo verifica la contrasena ya actualizada por el primero.
        String hashActual = cuentaRepository
                .bloquearCredencial(idCuenta)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.UNAUTHORIZED,
                        "NO_AUTENTICADO",
                        "La sesion no es valida"
                ));

        if (!passwordEncoder.matches(request.passwordActual(), hashActual)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CONTRASENA_ACTUAL_INCORRECTA",
                    "La contrasena actual no es correcta"
            );
        }

        cuentaRepository.actualizarContrasena(
                idCuenta,
                passwordEncoder.encode(request.passwordNueva())
        );

        String hashSesionActual = refreshTokenActual == null
                || refreshTokenActual.isBlank()
                ? null
                : TokenHash.sha256(refreshTokenActual);
        sesionRepository.revocarOtrasSesiones(idCuenta, hashSesionActual);
    }

    private void validar(CambiarContrasenaRequest request) {
        if (request == null
                || estaVacio(request.passwordActual())
                || estaVacio(request.passwordNueva())) {
            throw validacion("Falta un campo obligatorio");
        }
        if (request.passwordNueva().length() < minimumPasswordLength
                || request.passwordNueva()
                        .getBytes(StandardCharsets.UTF_8).length
                        > MAX_BCRYPT_PASSWORD_BYTES) {
            throw validacion(
                    "La contrasena nueva debe tener al menos "
                            + minimumPasswordLength + " caracteres"
            );
        }
    }

    private boolean estaVacio(String valor) {
        return valor == null || valor.isBlank();
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
