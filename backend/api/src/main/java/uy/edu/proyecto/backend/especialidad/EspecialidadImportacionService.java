package uy.edu.proyecto.backend.especialidad;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.csv.CsvArchivo;
import uy.edu.proyecto.backend.exception.ApiException;

/**
 * Carga masiva de especialidades (RF-30) segun la seccion 3.1.4: primero se
 * previsualiza (totales y motivo de cada fila con error) y al confirmar se
 * importan solo las filas validas; las invalidas se rechazan con su motivo.
 * Cada fila se inserta de forma independiente reutilizando el alta individual
 * (RF-29), por lo que un fallo de base de datos o de concurrencia rechaza
 * solo esa fila sin revertir las demas.
 */
@Service
public class EspecialidadImportacionService {

    private final EspecialidadRepository repository;
    private final EspecialidadService especialidadService;
    private final EspecialidadCsvValidador validador =
            new EspecialidadCsvValidador();

    public EspecialidadImportacionService(
            EspecialidadRepository repository,
            EspecialidadService especialidadService
    ) {
        this.repository = repository;
        this.especialidadService = especialidadService;
    }

    public PrevisualizacionEspecialidades previsualizar(String contenido) {
        List<FilaEspecialidadCsv> filas = validar(contenido);
        filas = marcarExistentes(filas);
        return resumir(filas);
    }

    public ResultadoImportacionEspecialidades confirmar(String contenido) {
        List<FilaEspecialidadCsv> filas = validar(contenido);

        List<FilaEspecialidadCsv> procesadas = new ArrayList<>();
        for (FilaEspecialidadCsv fila : filas) {
            if (!fila.valida()) {
                procesadas.add(fila);
                continue;
            }
            try {
                especialidadService.crear(fila.nombre(), fila.requierePase());
                procesadas.add(fila);
            } catch (ApiException exception) {
                procesadas.add(new FilaEspecialidadCsv(
                        fila.numero(),
                        fila.nombre(),
                        fila.requierePase(),
                        exception.getMessage()
                ));
            }
        }

        int total = procesadas.size();
        int rechazadas = (int) procesadas.stream()
                .filter(fila -> !fila.valida())
                .count();

        return new ResultadoImportacionEspecialidades(
                total,
                total - rechazadas,
                rechazadas,
                List.copyOf(procesadas),
                procesadas.stream()
                        .filter(fila -> !fila.valida())
                        .toList()
        );
    }

    private List<FilaEspecialidadCsv> validar(String contenido) {
        var filasCrudas = CsvArchivo.parsear(
                contenido,
                EspecialidadCsvValidador.COLUMNAS
        );
        return validador.validar(filasCrudas);
    }

    /** Marca como rechazadas las filas validas cuyo nombre ya existe en la base. */
    private List<FilaEspecialidadCsv> marcarExistentes(
            List<FilaEspecialidadCsv> filas
    ) {
        Set<String> nombres = filas.stream()
                .filter(FilaEspecialidadCsv::valida)
                .map(fila -> fila.nombre().toLowerCase(Locale.ROOT))
                .collect(Collectors.toSet());

        if (nombres.isEmpty()) {
            return filas;
        }

        Map<String, Especialidad> existentes =
                repository.buscarPorNombresLower(nombres);

        if (existentes.isEmpty()) {
            return filas;
        }

        List<FilaEspecialidadCsv> actualizadas = new ArrayList<>();
        for (FilaEspecialidadCsv fila : filas) {
            if (fila.valida()
                    && existentes.containsKey(
                            fila.nombre().toLowerCase(Locale.ROOT))) {
                actualizadas.add(new FilaEspecialidadCsv(
                        fila.numero(),
                        fila.nombre(),
                        fila.requierePase(),
                        "La especialidad ya existe en el sistema"
                ));
            } else {
                actualizadas.add(fila);
            }
        }
        return actualizadas;
    }

    private PrevisualizacionEspecialidades resumir(
            List<FilaEspecialidadCsv> filas
    ) {
        int total = filas.size();
        int invalidas = (int) filas.stream()
                .filter(fila -> !fila.valida())
                .count();

        return new PrevisualizacionEspecialidades(
                total,
                total - invalidas,
                invalidas,
                List.copyOf(filas),
                filas.stream()
                        .filter(fila -> !fila.valida())
                        .toList()
        );
    }
}
