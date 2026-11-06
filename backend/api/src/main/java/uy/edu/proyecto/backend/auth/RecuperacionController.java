package uy.edu.proyecto.backend.auth;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth/recuperacion")
public class RecuperacionController {

    private final RecuperacionService service;

    public RecuperacionController(RecuperacionService service) {
        this.service = service;
    }

    @PostMapping("/solicitar")
    public ResponseEntity<SolicitudPrimerIngresoResponse> solicitar(
            @RequestBody SolicitarRecuperacionRequest request
    ) {
        return ResponseEntity.accepted().body(service.solicitar(request));
    }

    @PostMapping("/validar")
    public ResponseEntity<Void> validar(
            @RequestBody(required = false) ValidarEnlaceRequest request
    ) {
        service.validarEnlace(request);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/completar")
    public ResponseEntity<Map<String, String>> completar(
            @RequestBody CompletarRecuperacionRequest request
    ) {
        service.completar(request);
        return ResponseEntity.ok(Map.of(
                "message",
                "Tu contraseña se actualizó correctamente. Ya podés iniciar sesión."
        ));
    }
}
