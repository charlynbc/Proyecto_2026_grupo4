package uy.edu.proyecto.backend.consultorio;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

@Service
public class ConsultorioImportacionService {

    private final ConsultorioRepository repository;

    private final ConsultorioCsvPrevisualizador previsualizador =
            new ConsultorioCsvPrevisualizador();

    public ConsultorioImportacionService(
            ConsultorioRepository repository
    ) {
        this.repository = repository;
    }

    public ConsultorioCsvPrevisualizador.Resultado previsualizar(
            String contenido
    ) {
        var resultado = previsualizador.previsualizar(contenido);

        if (resultado.validas() == 0) {
            return resultado;
        }

        Set<String> nombresExistentes = repository.listar()
                .stream()
                .map(consultorio -> normalizar(consultorio.nombre()))
                .collect(Collectors.toSet());

        var filasActualizadas =
                new ArrayList<ConsultorioCsvValidador.ResultadoFila>();

        for (var fila : resultado.filas()) {
            if (fila.valida()
                    && nombresExistentes.contains(normalizar(fila.nombre()))) {
                filasActualizadas.add(
                        new ConsultorioCsvValidador.ResultadoFila(
                                fila.numero(),
                                fila.nombre(),
                                fila.ubicacion(),
                                "El consultorio ya existe en el sistema"
                        )
                );
            } else {
                filasActualizadas.add(fila);
            }
        }

        var errores = filasActualizadas.stream()
                .filter(fila -> !fila.valida())
                .toList();

        int total = filasActualizadas.size();
        int invalidas = errores.size();
        int validas = total - invalidas;

        return new ConsultorioCsvPrevisualizador.Resultado(
                total,
                validas,
                invalidas,
                List.copyOf(filasActualizadas),
                errores
        );
    }

    private String normalizar(String nombre) {
        return nombre.trim().toLowerCase(Locale.ROOT);
    }
}
