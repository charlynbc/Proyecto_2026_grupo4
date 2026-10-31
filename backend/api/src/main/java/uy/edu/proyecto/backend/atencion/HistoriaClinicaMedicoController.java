package uy.edu.proyecto.backend.atencion;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
public class HistoriaClinicaMedicoController {

    private final HistoriaClinicaMedicoService service;

    public HistoriaClinicaMedicoController(HistoriaClinicaMedicoService service) {
        this.service = service;
    }

    @GetMapping("/api/medico/pacientes/{socioId}/historia-clinica")
    public List<HistoriaClinicaDTO> listar(
            @PathVariable String socioId,
            @AuthenticationPrincipal Jwt jwt) {
        Long id;
        try {
            id = Long.parseLong(socioId);
        } catch (NumberFormatException exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "El identificador del paciente debe ser positivo");
        }
        return service.listar(parsearMedicoId(jwt), id);
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
