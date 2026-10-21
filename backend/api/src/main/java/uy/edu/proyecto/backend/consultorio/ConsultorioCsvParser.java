package uy.edu.proyecto.backend.consultorio;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.apache.commons.csv.DuplicateHeaderMode;

public class ConsultorioCsvParser {

    public record Fila(
            int numero,
            String nombre,
            String ubicacion,
            String error
    ) {
    }

    public List<Fila> leer(String contenido) {
        if (contenido == null || contenido.isBlank()) {
            throw new IllegalArgumentException("El archivo CSV está vacío");
        }

        String texto = contenido.startsWith("\uFEFF")
                ? contenido.substring(1)
                : contenido;

        String encabezado = texto.lines()
                .findFirst()
                .orElse("");

        char separador = encabezado.contains(";") ? ';' : ',';

        CSVFormat formato = CSVFormat.DEFAULT.builder()
                .setDelimiter(separador)
                .setHeader()
                .setSkipHeaderRecord(true)
                .setIgnoreEmptyLines(true)
                .setDuplicateHeaderMode(DuplicateHeaderMode.DISALLOW)
                .get();

        try (CSVParser parser = CSVParser.parse(texto, formato)) {
            List<String> columnas = parser.getHeaderNames();

            if (columnas.size() != 2
                    || !columnas.containsAll(List.of("nombre", "ubicacion"))) {
                throw new IllegalArgumentException(
                        "El CSV debe tener las columnas nombre y ubicacion"
                );
            }

            List<Fila> filas = new ArrayList<>();
            int numero = 2;

            for (CSVRecord registro : parser) {
                if (registro.size() != 2) {
                    filas.add(new Fila(
                            numero,
                            null,
                            null,
                            "La fila debe tener exactamente 2 columnas"
                    ));
                } else {
                    filas.add(new Fila(
                            numero,
                            registro.get("nombre"),
                            registro.get("ubicacion"),
                            null
                    ));
                }

                numero++;
            }

            return filas;
        } catch (IOException exception) {
            throw new IllegalArgumentException(
                    "No se pudo leer el archivo CSV",
                    exception
            );
        }
    }
}
