package uy.edu.proyecto.backend.turno;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.exception.ApiErrorResponse;

@RestController
@RequestMapping("/api/turnos")
public class TurnoFechasController {

    private final TurnoFechasService service;

    public TurnoFechasController(TurnoFechasService service) {
        this.service = service;
    }

    @PostMapping("/suspensiones/previsualizar")
    public VistaPreviaSuspensionDTO previsualizar(
            @RequestBody PrevisualizarSuspensionRequest request
    ) {
        return service.previsualizar(request);
    }

    @PostMapping("/suspensiones")
    public ResultadoFechasDTO suspender(
            @RequestBody SuspenderFechasRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.suspender(request, funcionarioId(jwt));
    }

    @PostMapping("/rehabilitaciones")
    public ResultadoFechasDTO rehabilitar(
            @RequestBody RehabilitarFechasRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.rehabilitar(request, funcionarioId(jwt));
    }

    private Long funcionarioId(Jwt jwt) {
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

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiErrorResponse> solicitudMalFormada() {
        return ResponseEntity
                .badRequest()
                .body(new ApiErrorResponse(
                        "VALIDACION",
                        "El cuerpo de la solicitud tiene un formato inválido"
                ));
    }
}
