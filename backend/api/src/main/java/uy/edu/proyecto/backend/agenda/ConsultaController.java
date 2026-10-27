package uy.edu.proyecto.backend.agenda;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/consultas")
public class ConsultaController {

    private final ConsultaService service;
    private final ConsultaHistorialService historialService;
    private final CancelacionService cancelacionService;

    public ConsultaController(
            ConsultaService service,
            ConsultaHistorialService historialService,
            CancelacionService cancelacionService
    ) {
        this.service = service;
        this.historialService = historialService;
        this.cancelacionService = cancelacionService;
    }

    @GetMapping
    public ConsultaHistorialPageResponse listar(
            @RequestParam(name = "estado", required = false) String estado,
            @RequestParam(name = "fechaDesde", required = false) String fechaDesde,
            @RequestParam(name = "fechaHasta", required = false) String fechaHasta,
            @RequestParam(name = "especialidadId", required = false)
            String especialidadId,
            @RequestParam(name = "medicoId", required = false) String medicoId,
            @RequestParam(name = "orden", required = false) String orden,
            @RequestParam(name = "sentido", required = false) String sentido,
            @RequestParam(name = "page", required = false) String page,
            @RequestParam(name = "size", required = false) String size,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return historialService.listar(
                socioId(jwt),
                estado,
                fechaDesde,
                fechaHasta,
                especialidadId,
                medicoId,
                orden,
                sentido,
                page,
                size
        );
    }

    @GetMapping("/{id}")
    public ConsultaDTO detalle(
            @PathVariable String id,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return historialService.obtener(socioId(jwt), id);
    }

    @PostMapping
    public ResponseEntity<ConsultaDTO> agendar(
            @RequestBody CrearConsultaRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(service.agendar(socioId(jwt), request));
    }

    @PostMapping("/{id}/cancelar")
    public CancelacionDTO cancelar(
            @PathVariable String id,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return cancelacionService.cancelarPorSocio(socioId(jwt), id);
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
