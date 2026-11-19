package uy.edu.proyecto.backend.notificacion;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

/** GET /api/notificaciones (solo SOCIO): el socio sale siempre del token, nunca de un parametro. */
@RestController
@RequestMapping("/api/notificaciones")
public class NotificacionController {
    private final NotificacionService service;

    public NotificacionController(NotificacionService service) {
        this.service = service;
    }

    @GetMapping
    public NotificacionPageResponse listar(
            @RequestParam(name = "page", required = false) String page,
            @RequestParam(name = "size", required = false) String size,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.listar(socioId(jwt), page, size);
    }

    private static Long socioId(Jwt jwt) {
        try {
            long socioId = Long.parseLong(jwt.getSubject());
            if (socioId > 0) {
                return socioId;
            }
        } catch (NumberFormatException ignorada) {
            // Se informa abajo.
        }
        throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_INVALIDO", "La sesión no es válida");
    }
}
