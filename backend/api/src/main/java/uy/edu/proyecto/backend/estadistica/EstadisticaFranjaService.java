package uy.edu.proyecto.backend.estadistica;

import java.time.Clock;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class EstadisticaFranjaService {
    private final EstadisticaFranjaRepository repository;
    private final Clock clock;

    public EstadisticaFranjaService(EstadisticaFranjaRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public EstadisticaFranjaResponse calcular(String desde, String hasta, String vista,
            String especialidadId) {
        PeriodoEstadistico periodo = PeriodoEstadistico.resolver(desde, hasta, clock);
        String seleccion = vista == null || vista.isBlank()
                ? "CONSULTAS" : vista.trim().toUpperCase(Locale.ROOT);
        if (!seleccion.equals("CONSULTAS") && !seleccion.equals("LLEGADAS")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "vista debe ser CONSULTAS o LLEGADAS");
        }
        Long especialidad = IdFiltroEstadistico.resolver(especialidadId, "especialidadId");
        Map<Integer, Long> cantidades = new HashMap<>();
        for (var fila : repository.contar(periodo.desde(), periodo.hasta(), seleccion,
                especialidad)) {
            cantidades.put(fila.diaSemana() * 24 + fila.hora(), fila.cantidad());
        }
        List<EstadisticaFranjaResponse.Celda> celdas = new java.util.ArrayList<>(168);
        for (int dia = 1; dia <= 7; dia++) {
            for (int hora = 0; hora < 24; hora++) {
                celdas.add(new EstadisticaFranjaResponse.Celda(
                        dia, hora, cantidades.getOrDefault(dia * 24 + hora, 0L)));
            }
        }
        return new EstadisticaFranjaResponse(periodo.desde(), periodo.hasta(), seleccion,
                especialidad, celdas);
    }
}
