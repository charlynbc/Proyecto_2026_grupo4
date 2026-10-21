package uy.edu.proyecto.backend.usuario;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/usuarios")
public class AltaUsuarioController {

    private final AltaUsuarioService service;

    public AltaUsuarioController(AltaUsuarioService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<CuentaCreadaResponse> crear(
            @RequestBody AltaUsuarioRequest request
    ) {
        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(service.crear(request));
    }
}
