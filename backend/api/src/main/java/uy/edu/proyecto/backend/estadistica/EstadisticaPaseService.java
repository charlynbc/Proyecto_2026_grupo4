package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EstadisticaPaseService {
    private final EstadisticaPaseRepository repository;
    private final Clock clock;

    public EstadisticaPaseService(EstadisticaPaseRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public EstadisticaPaseResponse calcular(String desde, String hasta, String especialidadOrigenSolicitada) {
        PeriodoEstadistico periodo = PeriodoEstadistico.resolver(desde, hasta, clock);
        Long especialidadOrigenId = IdFiltroEstadistico.resolver(
                especialidadOrigenSolicitada, "especialidadOrigenId");
        var zona = clock.getZone();
        var items = repository.contar(
                        periodo.desde().atStartOfDay(zona).toInstant(),
                        periodo.hasta().plusDays(1).atStartOfDay(zona).toInstant(),
                        LocalDate.now(clock), especialidadOrigenId).stream()
                .map(f -> {
                    BigDecimal porcentaje = PorcentajeEstadistico.calcular(
                            f.utilizados(), f.utilizados() + f.vencidos());
                    return new EstadisticaPaseResponse.Item(f.destino(), f.emitidos(),
                            f.utilizados(), f.disponibles(), f.vencidos(),
                            porcentaje, PorcentajeEstadistico.texto(porcentaje));
                }).toList();
        return new EstadisticaPaseResponse(periodo.desde(), periodo.hasta(),
                especialidadOrigenId, items);
    }
}
