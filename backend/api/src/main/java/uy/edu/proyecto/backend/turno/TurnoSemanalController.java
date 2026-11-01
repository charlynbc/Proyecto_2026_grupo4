package uy.edu.proyecto.backend.turno;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/turnos-semanales")
public class TurnoSemanalController {

    private final TurnoSemanalService service;

    public TurnoSemanalController(TurnoSemanalService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<TurnoSemanalResponse> crear(
            @RequestBody AltaTurnoSemanalRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        Long idFuncionario;
        try {
            idFuncionario = Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(service.crear(request, idFuncionario));
    }

    @PatchMapping("/{id}")
    public TurnoSemanalResponse modificarConsultorio(
            @PathVariable Long id,
            @RequestBody ModificarTurnoSemanalRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        // El funcionario queda identificado por el JWT; RF-20 no registra
        // quien modifica, solo se exige el rol (SecurityConfig).
        try {
            Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
        return service.modificarConsultorio(id, request);
    }
}
