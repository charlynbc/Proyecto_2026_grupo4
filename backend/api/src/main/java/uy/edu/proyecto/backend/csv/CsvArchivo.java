package uy.edu.proyecto.backend.csv;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVRecord;
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

        byte[] bytes;
        try {
            bytes = archivo.getBytes();
        } catch (IOException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "No se pudo leer el archivo. Vuelva a seleccionarlo e"
                            + " intente de nuevo."
            );
        }

        if (esUtf16(bytes)) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "El archivo está guardado como Unicode (UTF-16) y no se"
                            + " puede leer. " + COMO_GUARDAR_UTF8
            );
        }

        try {
            return StandardCharsets.UTF_8
                    .newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes))
                    .toString();
        } catch (IOException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "El archivo no está guardado con codificación UTF-8, por"
                            + " eso las tildes y las eñes no se leen bien. "
                            + COMO_GUARDAR_UTF8
            );
        }
    }

    private static final String COMO_GUARDAR_UTF8 =
            "Guárdelo de nuevo como CSV UTF-8 (en Excel: Guardar como, tipo"
                    + " CSV UTF-8 delimitado por comas) y vuelva a cargarlo.";

    /**
     * UTF-16 se reconoce por su marca inicial (FF FE o FE FF) o por tener
     * bytes nulos: un CSV de texto nunca los contiene, pero UTF-16 sin marca
     * los tiene en cada caracter ASCII y de otro modo pasaria por UTF-8.
     */
    private static boolean esUtf16(byte[] bytes) {
        if (bytes.length >= 2) {
            int primero = bytes[0] & 0xFF;
            int segundo = bytes[1] & 0xFF;
            if ((primero == 0xFF && segundo == 0xFE)
                    || (primero == 0xFE && segundo == 0xFF)) {
                return true;
            }
        }
        for (byte valor : bytes) {
            if (valor == 0) {
                return true;
            }
        }
        return false;
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

        // Sin cabecera automatica: la primera fila se lee como una fila mas y se
        // valida a mano para poder explicar que esta mal.
        CSVFormat formato = CSVFormat.DEFAULT.builder()
                .setDelimiter(separador)
                .setIgnoreEmptyLines(true)
                .get();

        try (CSVParser parser = CSVParser.parse(texto, formato)) {
            Iterator<CSVRecord> registros = parser.iterator();
            if (!registros.hasNext()) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "CSV_INVALIDO",
                        "El archivo CSV está vacío o tiene un formato inválido"
                );
            }

            List<String> cabecera = registros.next().toList();
            validarCabecera(cabecera, columnas);
            List<Integer> posiciones = new ArrayList<>(columnas.size());
            for (String columna : columnas) {
                posiciones.add(cabecera.indexOf(columna));
            }

            List<FilaCruda> filas = new ArrayList<>();
            int numero = 2;

            while (registros.hasNext()) {
                CSVRecord registro = registros.next();
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
                    for (int posicion : posiciones) {
                        valores.add(registro.get(posicion));
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

    /**
     * Valida la primera fila y, si algo esta mal, dice que es y como
     * corregirlo. Orden: columnas sin nombre, columnas con espacios,
     * columnas repetidas y, al final, columnas que faltan o sobran.
     */
    private static void validarCabecera(List<String> cabecera, List<String> columnas) {
        List<Integer> sinNombre = new ArrayList<>();
        List<String> conEspacios = new ArrayList<>();
        for (int i = 0; i < cabecera.size(); i++) {
            String nombre = cabecera.get(i);
            if (nombre.isBlank()) {
                sinNombre.add(i + 1);
            } else if (!nombre.equals(nombre.trim())) {
                conEspacios.add("'" + nombre + "'");
            }
        }

        if (!sinNombre.isEmpty()) {
            throw cabeceraInvalida(
                    "La primera fila tiene columnas sin nombre ("
                            + (sinNombre.size() == 1 ? "posición " : "posiciones ")
                            + String.join(", ", sinNombre.stream()
                                    .map(String::valueOf).toList())
                            + "). Puede ser un separador de más al final:"
                            + " bórrelo y vuelva a cargar el archivo."
            );
        }

        if (!conEspacios.isEmpty()) {
            throw cabeceraInvalida(
                    "La primera fila tiene columnas con espacios al principio"
                            + " o al final: " + String.join(", ", conEspacios)
                            + ". Borre esos espacios y vuelva a cargar el"
                            + " archivo."
            );
        }

        List<String> vistas = new ArrayList<>();
        for (String nombre : cabecera) {
            if (vistas.contains(nombre)) {
                throw cabeceraInvalida(
                        "La columna '" + nombre + "' está repetida en la"
                                + " primera fila. Cada columna debe aparecer"
                                + " una sola vez."
                );
            }
            vistas.add(nombre);
        }

        List<String> faltan = columnas.stream()
                .filter(columna -> !cabecera.contains(columna))
                .toList();
        List<String> sobran = cabecera.stream()
                .filter(nombre -> !columnas.contains(nombre))
                .toList();
        if (faltan.isEmpty() && sobran.isEmpty()) {
            return;
        }

        StringBuilder mensaje = new StringBuilder(
                "El archivo no tiene las columnas esperadas.");
        if (!faltan.isEmpty()) {
            mensaje.append(faltan.size() == 1
                    ? " Falta la columna: " : " Faltan las columnas: ")
                    .append(String.join(", ", faltan)).append('.');
        }
        if (!sobran.isEmpty()) {
            mensaje.append(sobran.size() == 1
                    ? " Sobra la columna: " : " Sobran las columnas: ")
                    .append(String.join(", ", sobran)).append('.');
        }
        boolean soloCambiaLaCapitalizacion = sobran.stream().anyMatch(
                nombre -> faltan.stream().anyMatch(nombre::equalsIgnoreCase));
        if (soloCambiaLaCapitalizacion) {
            mensaje.append(" Los nombres de las columnas se escriben en"
                    + " minúsculas.");
        }
        mensaje.append(" Las columnas deben ser exactamente: ")
                .append(String.join(", ", columnas)).append('.');
        throw cabeceraInvalida(mensaje.toString());
    }

    private static ApiException cabeceraInvalida(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "CSV_INVALIDO", mensaje);
    }
}
