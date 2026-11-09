package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class EstadisticaInasistenciaService {
    private final EstadisticaInasistenciaRepository repository;
    private final Clock clock;

    public EstadisticaInasistenciaService(EstadisticaInasistenciaRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public EstadisticaInasistenciaResponse calcular(String desde, String hasta, String agruparPor) {
        PeriodoEstadistico periodo = PeriodoEstadistico.resolver(desde, hasta, clock);
        String grupo = agruparPor == null || agruparPor.isBlank()
                ? "ESPECIALIDAD" : agruparPor.trim().toUpperCase(java.util.Locale.ROOT);
        if (!grupo.equals("ESPECIALIDAD") && !grupo.equals("MEDICO")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "agruparPor debe ser ESPECIALIDAD o MEDICO");
        }
        var items = repository.contar(periodo.desde(), periodo.hasta(), LocalDate.now(clock),
                        grupo.equals("MEDICO")).stream()
                .map(f -> {
                    long total = f.atendidas() + f.noAsistio() + f.noSePresento() + f.noAtendidas();
                    BigDecimal porcentaje = PorcentajeEstadistico.calcular(
                            f.noAsistio() + f.noSePresento(), total);
                    return new EstadisticaInasistenciaResponse.Item(f.id(), f.nombre(), f.apellido(),
                            f.atendidas(), f.noAsistio(), f.noSePresento(), f.noAtendidas(),
                            total, porcentaje, PorcentajeEstadistico.texto(porcentaje));
                }).toList();
        return new EstadisticaInasistenciaResponse(periodo.desde(), periodo.hasta(), grupo, items);
    }
}
