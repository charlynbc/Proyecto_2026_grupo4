package uy.edu.proyecto.backend.estadistica;

import java.time.Clock;
import java.time.LocalDate;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EstadisticaEspecialidadService {

    private final EstadisticaEspecialidadRepository repository;
    private final Clock clock;

    public EstadisticaEspecialidadService(
            EstadisticaEspecialidadRepository repository,
            Clock clock
    ) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public EstadisticaEspecialidadResponse calcular(
            String desdeSolicitado,
            String hastaSolicitado
    ) {
        PeriodoEstadistico periodo = PeriodoEstadistico.resolver(
                desdeSolicitado, hastaSolicitado, clock);
        LocalDate desde = periodo.desde();
        LocalDate hasta = periodo.hasta();

        // Los limites se calculan en la zona del reloj de la aplicacion (America/Montevideo).
        var zona = clock.getZone();
        return new EstadisticaEspecialidadResponse(
                desde,
                hasta,
                repository.contarAgendadas(
                        desde.atStartOfDay(zona).toInstant(),
                        hasta.plusDays(1).atStartOfDay(zona).toInstant()
                )
        );
    }
}
