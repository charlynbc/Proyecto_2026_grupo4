package uy.edu.proyecto.backend.usuario;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

/**
 * Inactivacion y reactivacion de cuentas de empleado (RF-45). Acceso
 * exclusivo del rol ADMINISTRADOR (SecurityConfig); el administrador que
 * opera se toma del token y queda registrado en la auditoria.
 */
@RestController
@RequestMapping("/api/usuarios")
public class InactivacionEmpleadoController {

    private final InactivacionEmpleadoService service;

    public InactivacionEmpleadoController(InactivacionEmpleadoService service) {
        this.service = service;
    }

    @PostMapping("/{id}/inactivar")
    public EstadoCuentaResponse inactivar(
            @PathVariable long id,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.inactivar(id, idCuenta(jwt));
    }

    @PostMapping("/{id}/reactivar")
    public EstadoCuentaResponse reactivar(
            @PathVariable long id,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.reactivar(id, idCuenta(jwt));
    }

    private static Long idCuenta(Jwt jwt) {
        try {
            return Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException | NullPointerException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
    }
}
