package uy.edu.proyecto.backend.estadistica;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/estadisticas")
public class EstadisticaController {

    private final EstadisticaEspecialidadService especialidades;

    public EstadisticaController(EstadisticaEspecialidadService especialidades) {
        this.especialidades = especialidades;
    }

    @GetMapping("/especialidades")
    public EstadisticaEspecialidadResponse porEspecialidad(
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta
    ) {
        return especialidades.calcular(desde, hasta);
    }
}
