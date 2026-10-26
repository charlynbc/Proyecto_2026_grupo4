package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EstadisticaTurnoService {

    static final String SIN_DATOS = "Sin datos";

    private final EstadisticaTurnoRepository repository;
    private final Clock clock;

    public EstadisticaTurnoService(EstadisticaTurnoRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public EstadisticaTurnoResponse calcular(String desdeSolicitado, String hastaSolicitado) {
        PeriodoEstadistico periodo = PeriodoEstadistico.resolver(
                desdeSolicitado, hastaSolicitado, clock);
        return new EstadisticaTurnoResponse(
                periodo.desde(),
                periodo.hasta(),
                repository.contarUtilizacion(periodo.desde(), periodo.hasta()).stream()
                        .map(EstadisticaTurnoService::aDto)
                        .toList()
        );
    }

    // ocupados / ofrecidos * 100; denominador cero => "Sin datos", ocupacion cero con denominador => 0 %.
    static EstadisticaTurnoDTO aDto(EstadisticaTurnoRepository.Fila fila) {
        BigDecimal porcentaje = null;
        String texto = SIN_DATOS;
        if (fila.numerosOfrecidos() > 0) {
            porcentaje = BigDecimal.valueOf(fila.numerosOcupados())
                    .multiply(BigDecimal.valueOf(100))
                    .divide(BigDecimal.valueOf(fila.numerosOfrecidos()), 2, RoundingMode.HALF_UP);
            texto = porcentaje.stripTrailingZeros().toPlainString() + " %";
        }
        return new EstadisticaTurnoDTO(
                fila.turnoSemanalId(),
                fila.medico(),
                fila.especialidad(),
                fila.consultorio(),
                fila.diaSemana(),
                fila.fechasActivas(),
                fila.numerosOfrecidos(),
                fila.numerosOcupados(),
                porcentaje,
                texto
        );
    }
}
