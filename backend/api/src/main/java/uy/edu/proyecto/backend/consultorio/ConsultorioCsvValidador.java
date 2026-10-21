package uy.edu.proyecto.backend.consultorio;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class ConsultorioCsvValidador {

    public record ResultadoFila(
            int numero,
            String nombre,
            String ubicacion,
            String error
    ) {
        public boolean valida() {
            return error == null;
        }
    }

    public List<ResultadoFila> validar(
            List<ConsultorioCsvParser.Fila> filas
    ) {
        List<ResultadoFila> resultados = new ArrayList<>();
        Map<String, Integer> nombresVistos = new HashMap<>();

        for (ConsultorioCsvParser.Fila fila : filas) {
            if (fila.error() != null) {
                resultados.add(new ResultadoFila(
                        fila.numero(),
                        fila.nombre(),
                        fila.ubicacion(),
                        fila.error()
                ));
                continue;
            }

            String nombre = fila.nombre() == null
                    ? ""
                    : fila.nombre().trim();

            String ubicacion = fila.ubicacion() == null
                    ? ""
                    : fila.ubicacion().trim();

            String error = null;

            if (nombre.isBlank()) {
                error = "El nombre es obligatorio";
            } else if (ubicacion.isBlank()) {
                error = "La ubicación es obligatoria";
            } else if (nombre.length() > 120) {
                error = "El nombre supera 120 caracteres";
            } else if (ubicacion.length() > 200) {
                error = "La ubicación supera 200 caracteres";
            } else {
                String clave = nombre.toLowerCase(Locale.ROOT);
                Integer primeraFila = nombresVistos.putIfAbsent(
                        clave,
                        fila.numero()
                );

                if (primeraFila != null) {
                    error = "Nombre duplicado. Primera aparición válida en fila "
                            + primeraFila;
                }
            }

            resultados.add(new ResultadoFila(
                    fila.numero(),
                    nombre,
                    ubicacion,
                    error
            ));
        }

        return resultados;
    }
}
