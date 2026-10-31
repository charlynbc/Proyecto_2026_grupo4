package uy.edu.proyecto.backend.atencion;

import java.util.List;

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
@RequestMapping("/api/medico/atenciones")
public class AtencionMedicoController {

    private final AtencionMedicoService service;

    public AtencionMedicoController(AtencionMedicoService service) {
        this.service = service;
    }

    @GetMapping
    public List<AtencionMedicaDTO> listar(
            @RequestParam(name = "fechaDesde", required = false) String fechaDesde,
            @RequestParam(name = "fechaHasta", required = false) String fechaHasta,
            @RequestParam(name = "paciente", required = false) String paciente,
            @RequestParam(name = "especialidadId", required = false) String especialidadId,
            @RequestParam(name = "orden", required = false) String orden,
            @RequestParam(name = "sentido", required = false) String sentido,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.listar(
                parsearMedicoId(jwt),
                fechaDesde,
                fechaHasta,
                paciente,
                especialidadId,
                orden,
                sentido
        );
    }

    @GetMapping("/{idAtencion}")
    public AtencionMedicaDTO detalle(
            @PathVariable String idAtencion,
            @AuthenticationPrincipal Jwt jwt
    ) {
        Long id;
        try {
            id = Long.parseLong(idAtencion);
        } catch (NumberFormatException exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "El identificador de la atención debe ser positivo");
        }
        return service.detalle(parsearMedicoId(jwt), id);
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
