package uy.edu.proyecto.backend.estadistica;

import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

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

    private LocalDate fecha(String raw, String campo) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(raw.trim());
        } catch (DateTimeParseException exception) {
            throw validacion(campo + " debe tener formato YYYY-MM-DD");
        }
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
