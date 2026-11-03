package uy.edu.proyecto.backend.usuario;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth/cambio-correo")
public class CambioCorreoController {

    private final DatosPersonalesService service;

    public CambioCorreoController(DatosPersonalesService service) {
        this.service = service;
    }

    @PostMapping("/confirmar")
    public ResponseEntity<Map<String, String>> confirmar(
            @RequestBody ConfirmarCambioCorreoRequest request
    ) {
        service.confirmarCambioCorreo(request);
        return ResponseEntity.ok(Map.of(
                "message", "Tu correo se actualizó correctamente."
        ));
    }
}
