package uy.edu.proyecto.backend.estadistica;

import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

/** Periodo [desde, hasta] inclusivo, en fechas calendario de la zona del reloj de la aplicacion. */
record PeriodoEstadistico(LocalDate desde, LocalDate hasta) {

    /** Mes en curso por defecto; si falta un solo extremo se completa con el limite del mes en curso. */
    static PeriodoEstadistico resolver(String desdeSolicitado, String hastaSolicitado, Clock clock) {
        LocalDate hoy = LocalDate.now(clock);
        LocalDate desde = fecha(desdeSolicitado, "desde");
        LocalDate hasta = fecha(hastaSolicitado, "hasta");
        if (desde == null) {
            desde = hoy.withDayOfMonth(1);
        }
        if (hasta == null) {
            hasta = hoy.withDayOfMonth(hoy.lengthOfMonth());
        }
        if (desde.isAfter(hasta)) {
            throw validacion("desde no puede ser posterior a hasta");
        }
        return new PeriodoEstadistico(desde, hasta);
    }

    private static LocalDate fecha(String raw, String campo) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(raw.trim());
        } catch (DateTimeParseException exception) {
            throw validacion(campo + " debe tener formato YYYY-MM-DD");
        }
    }

    private static ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
