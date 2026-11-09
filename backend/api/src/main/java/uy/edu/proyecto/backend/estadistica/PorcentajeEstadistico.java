package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;
import java.math.RoundingMode;

final class PorcentajeEstadistico {
    private PorcentajeEstadistico() {}

    static BigDecimal calcular(long numerador, long denominador) {
        return denominador == 0 ? null : BigDecimal.valueOf(numerador)
                .multiply(BigDecimal.valueOf(100))
                .divide(BigDecimal.valueOf(denominador), 2, RoundingMode.HALF_UP);
    }

    static String texto(BigDecimal porcentaje) {
        return porcentaje == null ? "Sin datos"
                : porcentaje.stripTrailingZeros().toPlainString() + " %";
    }
}
