package uy.edu.proyecto.backend.estadistica;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/estadisticas")
public class EstadisticaController {

    private final EstadisticaEspecialidadService especialidades;
    private final EstadisticaTurnoService turnos;
    private final EstadisticaConsultaService consultas;

    public EstadisticaController(
            EstadisticaEspecialidadService especialidades,
            EstadisticaTurnoService turnos,
            EstadisticaConsultaService consultas
    ) {
        this.especialidades = especialidades;
        this.turnos = turnos;
        this.consultas = consultas;
    }

    @GetMapping("/consultas")
    public EstadisticaConsultaResponse porConsulta(
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta
    ) {
        return consultas.calcular(desde, hasta);
    }

    @GetMapping("/turnos")
    public EstadisticaTurnoResponse porTurno(
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta
    ) {
        return turnos.calcular(desde, hasta);
    }

    @GetMapping("/especialidades")
    public EstadisticaEspecialidadResponse porEspecialidad(
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta
    ) {
        return especialidades.calcular(desde, hasta);
    }
}
