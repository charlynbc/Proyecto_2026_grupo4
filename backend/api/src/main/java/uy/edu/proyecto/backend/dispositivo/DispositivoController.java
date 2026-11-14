package uy.edu.proyecto.backend.dispositivo;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/dispositivos")
public class DispositivoController {

    private final DispositivoService service;

    public DispositivoController(DispositivoService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<DispositivoDTO> registrar(
            @RequestBody DispositivoRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        DispositivoRegistro registro =
                service.registrar(socioId(jwt), request.token());
        return ResponseEntity.ok(registro.dispositivo());
    }

    @PostMapping("/baja")
    public ResponseEntity<Void> darDeBaja(
            @RequestBody DispositivoRequest request,
            @AuthenticationPrincipal Jwt jwt
    ) {
        service.darDeBaja(socioId(jwt), request.token());
        return ResponseEntity.noContent().build();
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
