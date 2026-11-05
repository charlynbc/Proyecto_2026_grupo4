package uy.edu.proyecto.backend.consultorio;

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
 * Carga masiva de consultorios (RF-34) segun la seccion 3.1.4: primero se
 * previsualiza (totales y motivo de cada fila con error) y al confirmar se
 * importan solo las filas validas; las invalidas se rechazan con su motivo.
 * Cada fila se inserta de forma independiente reutilizando el alta individual
 * (RF-33), por lo que un fallo de base de datos o de concurrencia rechaza
 * solo esa fila sin revertir las demas.
 */
@Service
public class ConsultorioImportacionService {

    private final ConsultorioRepository repository;
    private final ConsultorioService consultorioService;
    private final ConsultorioCsvValidador validador =
            new ConsultorioCsvValidador();

    public ConsultorioImportacionService(
            ConsultorioRepository repository,
            ConsultorioService consultorioService
    ) {
        this.repository = repository;
        this.consultorioService = consultorioService;
    }

    public PrevisualizacionConsultorios previsualizar(String contenido) {
        List<FilaConsultorioCsv> filas = validar(contenido);
        filas = marcarExistentes(filas);
        return resumir(filas);
    }

    public ResultadoImportacionConsultorios confirmar(String contenido) {
        List<FilaConsultorioCsv> filas = validar(contenido);
        filas = marcarExistentes(filas);

        List<FilaConsultorioCsv> procesadas = new ArrayList<>();
        for (FilaConsultorioCsv fila : filas) {
            if (!fila.valida()) {
                procesadas.add(fila);
                continue;
            }
            try {
                consultorioService.crear(fila.nombre(), fila.ubicacion());
                procesadas.add(fila);
            } catch (ApiException exception) {
                procesadas.add(new FilaConsultorioCsv(
                        fila.numero(),
                        fila.nombre(),
                        fila.ubicacion(),
                        exception.getMessage()
                ));
            }
        }

        int total = procesadas.size();
        int rechazadas = (int) procesadas.stream()
                .filter(fila -> !fila.valida())
                .count();

        return new ResultadoImportacionConsultorios(
                total,
                total - rechazadas,
                rechazadas,
                List.copyOf(procesadas),
                procesadas.stream()
                        .filter(fila -> !fila.valida())
                        .toList()
        );
    }

    private List<FilaConsultorioCsv> validar(String contenido) {
        var filasCrudas = CsvArchivo.parsear(
                contenido,
                ConsultorioCsvValidador.COLUMNAS
        );
        return validador.validar(filasCrudas);
    }

    /** Marca como rechazadas las filas validas cuyo nombre ya existe en la base. */
    private List<FilaConsultorioCsv> marcarExistentes(
            List<FilaConsultorioCsv> filas
    ) {
        Set<String> nombres = filas.stream()
                .filter(FilaConsultorioCsv::valida)
                .map(fila -> fila.nombre().toLowerCase(Locale.ROOT))
                .collect(Collectors.toSet());

        if (nombres.isEmpty()) {
            return filas;
        }

        Map<String, Consultorio> existentes =
                repository.buscarPorNombresLower(nombres);

        if (existentes.isEmpty()) {
            return filas;
        }

        List<FilaConsultorioCsv> actualizadas = new ArrayList<>();
        for (FilaConsultorioCsv fila : filas) {
            if (fila.valida()
                    && existentes.containsKey(
                            fila.nombre().toLowerCase(Locale.ROOT))) {
                actualizadas.add(new FilaConsultorioCsv(
                        fila.numero(),
                        fila.nombre(),
                        fila.ubicacion(),
                        "El consultorio ya existe en el sistema"
                ));
            } else {
                actualizadas.add(fila);
            }
        }
        return actualizadas;
    }

    private PrevisualizacionConsultorios resumir(
            List<FilaConsultorioCsv> filas
    ) {
        int total = filas.size();
        int invalidas = (int) filas.stream()
                .filter(fila -> !fila.valida())
                .count();

        return new PrevisualizacionConsultorios(
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
