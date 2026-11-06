package uy.edu.proyecto.backend.csv;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
import org.apache.commons.csv.DuplicateHeaderMode;
import org.springframework.http.HttpStatus;
import org.springframework.web.multipart.MultipartFile;

import uy.edu.proyecto.backend.exception.ApiException;

/**
 * Soporte compartido de las cargas masivas CSV (seccion 3.1.4 de
 * Requerimientos): decodificacion UTF-8 estricta, separador coma o punto y
 * coma, encabezados exactos y limite de filas. Los archivos se procesan en
 * memoria y no se almacenan.
 */
public final class CsvArchivo {
    public static final long MAX_BYTES = 1024L * 1024L;

    /** Maximo de filas de datos admitidas por archivo (documentado en el contrato). */
    public static final int MAX_FILAS = 1000;

    private CsvArchivo() {
    }

    /** Fila de datos ya separada en columnas; error != null si esta mal formada. */
    public record FilaCruda(
            int numero,
            List<String> valores,
            String error
    ) {
        public String valor(int indice) {
            return indice < valores.size() ? valores.get(indice) : null;
        }
    }

    /**
     * Lee el contenido del archivo como UTF-8 estricto. Rechaza archivos
     * ausentes, vacios o con bytes que no sean UTF-8 valido.
     */
    public static String leerUtf8(MultipartFile archivo) {
        if (archivo == null || archivo.isEmpty()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "Debe seleccionar un archivo CSV no vacío"
            );
        }
        if (archivo.getSize() > MAX_BYTES) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CSV_INVALIDO",
                    "El archivo supera el tamaño máximo permitido (1 MB)");
        }

        try {
            return StandardCharsets.UTF_8
                    .newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(archivo.getBytes()))
                    .toString();
        } catch (IOException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "No se pudo leer el archivo como UTF-8"
            );
        } catch (RuntimeException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "El archivo no es texto UTF-8 válido"
            );
        }
    }

    /**
     * Parsea el contenido con encabezados. El separador es coma o punto y
     * coma, detectado en la linea de encabezado. Las columnas deben ser
     * exactamente las esperadas (ni faltantes ni adicionales, sin repetir).
     * Cada fila con una cantidad distinta de columnas queda marcada con
     * error; las demas conservan sus valores crudos por posicion.
     */
    public static List<FilaCruda> parsear(String contenido, List<String> columnas) {
        if (contenido == null || contenido.isBlank()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "El archivo CSV está vacío o tiene un formato inválido"
            );
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
            List<String> columnasLeidas = parser.getHeaderNames()
                    .stream()
                    .map(String::trim)
                    .toList();

            if (columnasLeidas.size() != columnas.size()
                    || !columnasLeidas.containsAll(columnas)) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "CSV_INVALIDO",
                        "El CSV debe tener exactamente las columnas: "
                                + String.join(", ", columnas)
                );
            }

            List<FilaCruda> filas = new ArrayList<>();
            int numero = 2;

            for (CSVRecord registro : parser) {
                if (filas.size() >= MAX_FILAS) {
                    throw new ApiException(
                            HttpStatus.BAD_REQUEST,
                            "CSV_INVALIDO",
                            "El archivo supera el máximo de "
                                    + MAX_FILAS + " filas de datos"
                    );
                }

                if (registro.size() != columnas.size()) {
                    filas.add(new FilaCruda(
                            numero,
                            List.of(),
                            "La fila debe tener exactamente "
                                    + columnas.size() + " columnas"
                    ));
                } else {
                    List<String> valores = new ArrayList<>(columnas.size());
                    for (String columna : columnas) {
                        valores.add(registro.get(columna));
                    }
                    filas.add(new FilaCruda(numero, valores, null));
                }

                numero++;
            }

            return filas;
        } catch (IllegalArgumentException | IOException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "El archivo CSV está vacío o tiene un formato inválido"
            );
        }
    }
}
