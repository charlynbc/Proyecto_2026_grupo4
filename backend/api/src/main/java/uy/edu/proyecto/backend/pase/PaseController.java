package uy.edu.proyecto.backend.pase;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/socios/me/pases")
public class PaseController {

    private final PaseService service;

    public PaseController(PaseService service) {
        this.service = service;
    }

    @GetMapping("/disponibles")
    public List<PaseDTO> disponibles(@AuthenticationPrincipal Jwt jwt) {
        return service.listarDisponibles(socioId(jwt));
    }

    private Long socioId(Jwt jwt) {
        try {
            Long socioId = Long.parseLong(jwt.getSubject());
            if (socioId <= 0) {
                throw new NumberFormatException("El identificador no es positivo");
            }
            return socioId;
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
    }
}
