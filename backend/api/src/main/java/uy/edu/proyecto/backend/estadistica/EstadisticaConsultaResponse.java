package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;

/**
 * Consultas del periodo por estado efectivo. {@code porcentajeCancelacion} es null cuando el total es cero;
 * {@code porcentajeCancelacionTexto} es la representacion para mostrar ("Sin datos" o "12.5 %").
 */
public record EstadisticaConsultaResponse(
        LocalDate desde,
        LocalDate hasta,
        Map<String, Long> estados,
        long totalConsultas,
        long canceladasPorSocio,
        BigDecimal porcentajeCancelacion,
        String porcentajeCancelacionTexto
) {
}
