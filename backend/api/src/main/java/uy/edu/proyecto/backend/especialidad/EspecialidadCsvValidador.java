package uy.edu.proyecto.backend.especialidad;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import uy.edu.proyecto.backend.csv.CsvArchivo;

/**
 * Validaciones por fila del CSV de especialidades (RF-30): mismas reglas del
 * alta individual (RF-29) mas la deteccion de repetidas dentro del archivo,
 * conservando la primera aparicion (seccion 3.1.4).
 */
public class EspecialidadCsvValidador {

    static final List<String> COLUMNAS = List.of("nombre", "requiere_pase");

    public List<FilaEspecialidadCsv> validar(List<CsvArchivo.FilaCruda> filas) {
        List<FilaEspecialidadCsv> resultados = new ArrayList<>();
        Map<String, Integer> nombresVistos = new HashMap<>();

        for (CsvArchivo.FilaCruda fila : filas) {
            if (fila.error() != null) {
                resultados.add(new FilaEspecialidadCsv(
                        fila.numero(),
                        null,
                        null,
                        fila.error()
                ));
                continue;
            }

            String nombre = fila.valor(0) == null ? "" : fila.valor(0).trim();
            String paseTexto = fila.valor(1) == null ? "" : fila.valor(1).trim();

            String error = null;
            Boolean requierePase = null;

            if (nombre.isBlank()) {
                error = "El nombre es obligatorio";
            } else if (nombre.length() > 120) {
                error = "El nombre supera 120 caracteres";
            } else if (paseTexto.isBlank()) {
                error = "La columna requiere_pase es obligatoria (si o no)";
            } else {
                requierePase = parsearSiNo(paseTexto);
                if (requierePase == null) {
                    error = "requiere_pase debe ser si o no";
                }
            }

            if (error == null) {
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

            resultados.add(new FilaEspecialidadCsv(
                    fila.numero(),
                    nombre,
                    requierePase,
                    error
            ));
        }

        return resultados;
    }

    /** Valores admitidos por RF-30: si (con o sin tilde) o no, sin importar mayusculas. */
    private Boolean parsearSiNo(String valor) {
        String normalizado = valor.toLowerCase(Locale.ROOT);
        if (normalizado.equals("si") || normalizado.equals("sí")) {
            return Boolean.TRUE;
        }
        if (normalizado.equals("no")) {
            return Boolean.FALSE;
        }
        return null;
    }
}
