package uy.edu.proyecto.backend.consultorio;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/consultorios")
public class ConsultorioController {

    private final ConsultorioService service;

    public ConsultorioController(ConsultorioService service) {
        this.service = service;
    }

    @GetMapping
    public Map<String, List<Consultorio>> listar() {
        return Map.of("items", service.listar());
    }

    @PostMapping
    public ResponseEntity<Consultorio> crear(
            @RequestBody CrearConsultorioRequest request
    ) {
        Consultorio nuevo = service.crear(
                request.nombre(),
                request.ubicacion()
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(nuevo);
    }
}
