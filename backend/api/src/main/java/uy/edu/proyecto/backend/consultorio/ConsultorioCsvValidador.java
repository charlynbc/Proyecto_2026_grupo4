package uy.edu.proyecto.backend.consultorio;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import uy.edu.proyecto.backend.csv.CsvArchivo;

/**
 * Validaciones por fila del CSV de consultorios (RF-34): mismas reglas del
 * alta individual (RF-33) mas la deteccion de repetidas dentro del archivo,
 * conservando la primera aparicion (seccion 3.1.4).
 */
public class ConsultorioCsvValidador {

    static final List<String> COLUMNAS = List.of("nombre", "ubicacion");

    public List<FilaConsultorioCsv> validar(List<CsvArchivo.FilaCruda> filas) {
        List<FilaConsultorioCsv> resultados = new ArrayList<>();
        Map<String, Integer> nombresVistos = new HashMap<>();

        for (CsvArchivo.FilaCruda fila : filas) {
            if (fila.error() != null) {
                resultados.add(new FilaConsultorioCsv(
                        fila.numero(),
                        null,
                        null,
                        fila.error()
                ));
                continue;
            }

            String nombre = fila.valor(0) == null ? "" : fila.valor(0).trim();
            String ubicacion = fila.valor(1) == null ? "" : fila.valor(1).trim();

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

            resultados.add(new FilaConsultorioCsv(
                    fila.numero(),
                    nombre,
                    ubicacion,
                    error
            ));
        }

        return resultados;
    }
}
