package uy.edu.proyecto.backend.aviso;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.agenda.ConsultaDTO;
import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/avisos-llegada")
public class AvisoLlegadaController {

    private final AvisoLlegadaService service;

    public AvisoLlegadaController(AvisoLlegadaService service) {
        this.service = service;
    }

    @GetMapping("/consultas-hoy")
    public ItemsConsultas consultasDeHoy(
            @RequestParam(name = "ci") String ci
    ) {
        return new ItemsConsultas(service.consultasDeHoy(ci));
    }

    @PostMapping
    public ResponseEntity<AvisoLlegadaDTO> registrar(
            @RequestBody AvisoLlegadaRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        Long funcionarioId;
        try {
            funcionarioId = Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }

        ResultadoAvisoLlegada resultado =
                service.registrar(request == null ? null : request.ci(), funcionarioId);
        return ResponseEntity
                .status(resultado.creado()
                        ? HttpStatus.CREATED
                        : HttpStatus.OK)
                .body(resultado.aviso());
    }

    public record ItemsConsultas(List<ConsultaDTO> items) {
    }
}
