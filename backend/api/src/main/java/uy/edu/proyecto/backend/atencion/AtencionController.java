package uy.edu.proyecto.backend.atencion;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
public class AtencionController {

    private final AtencionService service;

    public AtencionController(AtencionService service) {
        this.service = service;
    }

    @PostMapping("/api/medico/consultas/{id}/resultado")
    public ResultadoConsultaResponse registrarResultado(
            @PathVariable Long id,
            @RequestBody ResultadoConsultaRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.registrarResultado(
                parsearMedicoId(jwt),
                id,
                request
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
