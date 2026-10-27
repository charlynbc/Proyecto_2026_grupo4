package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EstadisticaConsultaService {

    static final String SIN_DATOS = "Sin datos";
    static final String CANCELADA_SOCIO = "CANCELADA_SOCIO";
    static final List<String> ESTADOS = List.of(
            "AGENDADA",
            "ATENDIDA",
            CANCELADA_SOCIO,
            "CANCELADA_INSTITUCION",
            "NO_ASISTIO",
            "NO_ATENDIDA",
            "NO_SE_PRESENTO"
    );

    private final EstadisticaConsultaRepository repository;
    private final Clock clock;

    public EstadisticaConsultaService(EstadisticaConsultaRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public EstadisticaConsultaResponse calcular(String desdeSolicitado, String hastaSolicitado) {
        PeriodoEstadistico periodo = PeriodoEstadistico.resolver(
                desdeSolicitado, hastaSolicitado, clock);
        Map<String, Long> contados = repository.contarPorEstado(
                periodo.desde(), periodo.hasta(), LocalDate.now(clock));
        return armar(periodo, contados);
    }

    // canceladasSocio / total * 100; total cero => "Sin datos"; con total y sin canceladas => "0 %".
    static EstadisticaConsultaResponse armar(PeriodoEstadistico periodo, Map<String, Long> contados) {
        Map<String, Long> estados = new LinkedHashMap<>();
        long total = 0;
        for (String estado : ESTADOS) {
            long cantidad = contados.getOrDefault(estado, 0L);
            estados.put(estado, cantidad);
            total += cantidad;
        }
        long canceladas = estados.get(CANCELADA_SOCIO);
        BigDecimal porcentaje = null;
        String texto = SIN_DATOS;
        if (total > 0) {
            porcentaje = BigDecimal.valueOf(canceladas)
                    .multiply(BigDecimal.valueOf(100))
                    .divide(BigDecimal.valueOf(total), 2, RoundingMode.HALF_UP);
            texto = porcentaje.stripTrailingZeros().toPlainString() + " %";
        }
        return new EstadisticaConsultaResponse(
                periodo.desde(), periodo.hasta(), estados, total, canceladas, porcentaje, texto);
    }
}
