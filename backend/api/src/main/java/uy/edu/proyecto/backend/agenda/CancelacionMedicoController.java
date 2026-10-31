package uy.edu.proyecto.backend.agenda;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
public class CancelacionMedicoController {

    private final CancelacionMedicoService service;

    public CancelacionMedicoController(CancelacionMedicoService service) {
        this.service = service;
    }

    @PostMapping("/api/medico/consultas/{id}/cancelar")
    public CancelacionDTO cancelarConsulta(
            @PathVariable String id,
            @RequestBody(required = false) CancelacionMedicoRequest request,
            @AuthenticationPrincipal Jwt jwt) {
        return service.cancelarConsulta(
                parsearMedicoId(jwt), id, request == null ? null : request.motivo());
    }

    @PostMapping("/api/medico/turnos/{id}/cancelar")
    public CancelacionTurnoMedicoDTO cancelarTurno(
            @PathVariable String id,
            @RequestBody(required = false) CancelacionMedicoRequest request,
            @AuthenticationPrincipal Jwt jwt) {
        return service.cancelarTurno(
                parsearMedicoId(jwt), id, request == null ? null : request.motivo());
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
