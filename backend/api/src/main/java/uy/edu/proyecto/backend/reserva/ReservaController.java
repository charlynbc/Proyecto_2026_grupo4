package uy.edu.proyecto.backend.reserva;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/reservas")
public class ReservaController {

    private final ReservaService reservaService;

    public ReservaController(
            ReservaService reservaService
    ) {
        this.reservaService = reservaService;
    }

    @PostMapping
    public ResponseEntity<Reserva> crear(
            @AuthenticationPrincipal
            Jwt jwt,

            @Valid
            @RequestBody
            CrearReservaRequest request
    ) {

        Long usuarioId = Long.valueOf(
                jwt.getSubject()
        );

        Reserva reserva =
                reservaService.crear(
                        usuarioId,
                        request
                );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(reserva);
    }
}
