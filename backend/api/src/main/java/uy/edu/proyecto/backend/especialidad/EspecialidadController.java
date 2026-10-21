package uy.edu.proyecto.backend.especialidad;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/especialidades")
public class EspecialidadController {

    private final EspecialidadService service;

    public EspecialidadController(EspecialidadService service) {
        this.service = service;
    }

    @GetMapping
    public Map<String, List<Especialidad>> listar() {
        return Map.of("items", service.listar());
    }

    @PostMapping
    public ResponseEntity<Especialidad> crear(
            @RequestBody CrearEspecialidadRequest request
    ) {
        if (request.requierePase() == null) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El campo requierePase es obligatorio"
            );
        }

        Especialidad nueva = service.crear(
                request.nombre(),
                request.requierePase()
        );

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(nueva);
    }
}
