package uy.edu.proyecto.backend.reserva;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class ReservaConsultaController {

    private final ReservaConsultaService service;

    public ReservaConsultaController(ReservaConsultaService service) {
        this.service = service;
    }

    @GetMapping("/mis-reservas")
    public List<ReservaHistorial> misReservas(@AuthenticationPrincipal Jwt jwt) {
        Long usuarioId = Long.valueOf(jwt.getSubject());
        return service.listar(usuarioId);
    }

    @PatchMapping("/reservas/{id}/cancelacion")
    public ResponseEntity<ReservaCancelada> cancelar(
            @PathVariable Long id,
            @AuthenticationPrincipal Jwt jwt
    ) {
        Long usuarioId = Long.valueOf(jwt.getSubject());
        ReservaCancelada reserva = service.cancelar(id, usuarioId);
        return ResponseEntity.ok(reserva);
    }
}