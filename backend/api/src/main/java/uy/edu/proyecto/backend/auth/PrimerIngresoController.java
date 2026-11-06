package uy.edu.proyecto.backend.auth;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth/primer-ingreso")
public class PrimerIngresoController {

    private final PrimerIngresoService service;

    public PrimerIngresoController(PrimerIngresoService service) {
        this.service = service;
    }

    @PostMapping("/solicitar")
    public ResponseEntity<SolicitudPrimerIngresoResponse> solicitar(
            @RequestBody SolicitarPrimerIngresoRequest request
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
    public ResponseEntity<CuentaActivadaResponse> completar(
            @RequestBody CompletarPrimerIngresoRequest request
    ) {
        return ResponseEntity.ok(service.completar(request));
    }
}
