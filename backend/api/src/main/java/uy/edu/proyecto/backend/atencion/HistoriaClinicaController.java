package uy.edu.proyecto.backend.atencion;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
public class HistoriaClinicaController {

    private final HistoriaClinicaService service;

    public HistoriaClinicaController(HistoriaClinicaService service) {
        this.service = service;
    }

    @GetMapping("/api/historia-clinica")
    public List<HistoriaClinicaDTO> listar(
            @RequestParam(name = "fechaDesde", required = false) String fechaDesde,
            @RequestParam(name = "fechaHasta", required = false) String fechaHasta,
            @RequestParam(name = "especialidadId", required = false) String especialidadId,
            @RequestParam(name = "medicoId", required = false) String medicoId,
            @RequestParam(name = "texto", required = false) String texto,
            @RequestParam(name = "orden", required = false) String orden,
            @RequestParam(name = "sentido", required = false) String sentido,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.listar(
                socioId(jwt),
                fechaDesde,
                fechaHasta,
                especialidadId,
                medicoId,
                texto,
                orden,
                sentido
        );
    }

    @GetMapping("/api/historia-clinica/{idAtencion}")
    public HistoriaClinicaDTO detalle(
            @PathVariable String idAtencion,
            @AuthenticationPrincipal Jwt jwt
    ) {
        Long id;
        try {
            id = Long.parseLong(idAtencion);
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "idAtencion debe ser un identificador válido"
            );
        }
        return service.detalle(socioId(jwt), id);
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
