package uy.edu.proyecto.backend.especialidad;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
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
    public Map<String, List<Especialidad>> listar(
            @RequestParam(required = false) String nombre,
            @RequestParam(required = false) String requierePase,
            @RequestParam(required = false) String orden
    ) {
        if (nombre == null && requierePase == null && orden == null) {
            return Map.of("items", service.listar());
        }
        return Map.of("items", service.listar(nombre, requierePase, orden));
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

    /** Correccion administrativa de nombre y/o exigencia de pase (RF-38). */
    @PatchMapping("/{id}")
    public Especialidad corregir(
            @PathVariable long id,
            @RequestBody CorregirEspecialidadRequest request
    ) {
        if (request == null) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El cuerpo de la solicitud es obligatorio"
            );
        }
        return service.corregir(id, request.nombre(), request.requierePase());
    }
}
