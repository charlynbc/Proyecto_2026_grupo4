package uy.edu.proyecto.backend.turno;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/medico/turnos")
public class TurnoMedicoController {

    private final TurnoMedicoService service;

    public TurnoMedicoController(TurnoMedicoService service) {
        this.service = service;
    }

    @GetMapping
    public TurnosMedicoResponse listar(
            @RequestParam(name = "fecha") String fecha,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.listar(parsearMedicoId(jwt), fecha);
    }

    @GetMapping("/{id}/numeros")
    public NumerosTurnoMedicoResponse obtenerNumeros(
            @PathVariable Long id,
            @RequestParam(name = "llegada", required = false) Boolean llegada,
            @RequestParam(name = "orden", required = false) String orden,
            @RequestParam(name = "sentido", required = false) String sentido,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.obtenerNumeros(
                parsearMedicoId(jwt),
                id,
                llegada,
                orden,
                sentido
        );
    }

    private Long parsearMedicoId(Jwt jwt) {
        try {
            return Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
    }
}
