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
    private final EstadisticaInasistenciaService inasistencias;
    private final EstadisticaPaseService pases;
    private final EstadisticaFranjaService franjas;

    public EstadisticaController(
            EstadisticaEspecialidadService especialidades,
            EstadisticaTurnoService turnos,
            EstadisticaConsultaService consultas,
            EstadisticaInasistenciaService inasistencias,
            EstadisticaPaseService pases,
            EstadisticaFranjaService franjas
    ) {
        this.especialidades = especialidades;
        this.turnos = turnos;
        this.consultas = consultas;
        this.inasistencias = inasistencias;
        this.pases = pases;
        this.franjas = franjas;
    }

    @GetMapping("/inasistencias")
    public EstadisticaInasistenciaResponse inasistencias(
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta,
            @RequestParam(required = false) String agruparPor
    ) {
        return inasistencias.calcular(desde, hasta, agruparPor);
    }

    @GetMapping("/pases")
    public EstadisticaPaseResponse pases(
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta,
            @RequestParam(required = false) String especialidadOrigenId
    ) {
        return pases.calcular(desde, hasta, especialidadOrigenId);
    }

    @GetMapping("/franjas")
    public EstadisticaFranjaResponse franjas(
            @RequestParam(required = false) String desde,
            @RequestParam(required = false) String hasta,
            @RequestParam(required = false) String vista,
            @RequestParam(required = false) String especialidadId
    ) {
        return franjas.calcular(desde, hasta, vista, especialidadId);
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
