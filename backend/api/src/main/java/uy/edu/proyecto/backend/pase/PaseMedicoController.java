package uy.edu.proyecto.backend.pase;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/medico/pases")
public class PaseMedicoController {

    private final PaseMedicoService service;

    public PaseMedicoController(PaseMedicoService service) {
        this.service = service;
    }

    @GetMapping
    public List<PaseEmitidoDTO> listar(
            @RequestParam(name = "situacion", required = false) String situacion,
            @RequestParam(name = "orden", required = false) String orden,
            @RequestParam(name = "sentido", required = false) String sentido,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.listar(parsearMedicoId(jwt), situacion, orden, sentido);
    }

    private Long parsearMedicoId(Jwt jwt) {
        try {
            return Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_INVALIDO",
                    "La sesión no es válida");
        }
    }
}
