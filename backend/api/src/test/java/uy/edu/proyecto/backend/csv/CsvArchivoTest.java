package uy.edu.proyecto.backend.csv;

import java.nio.charset.StandardCharsets;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CsvArchivoTest {

    private static final List<String> COLUMNAS = List.of("nombre", "requiere_pase");

    @Test
    void leeArchivoUtf8ConTildes() {
        var archivo = new MockMultipartFile(
                "archivo",
                "especialidades.csv",
                "text/csv",
                "nombre,requiere_pase\nCardiología,si\n".getBytes(StandardCharsets.UTF_8)
        );

        String contenido = CsvArchivo.leerUtf8(archivo);

        assertTrue(contenido.contains("Cardiología"));
    }

    @Test
    void rechazaArchivoNuloOVacio() {
        ApiException nulo = assertThrows(
                ApiException.class,
                () -> CsvArchivo.leerUtf8(null)
        );
        assertEquals(HttpStatus.BAD_REQUEST, nulo.getStatus());
        assertEquals("CSV_INVALIDO", nulo.getCode());

        var vacio = new MockMultipartFile("archivo", new byte[0]);
        ApiException vacia = assertThrows(
                ApiException.class,
                () -> CsvArchivo.leerUtf8(vacio)
        );
        assertEquals("CSV_INVALIDO", vacia.getCode());
    }

    @Test
    void mantieneLimiteDeUnMegabyteParaCsv() {
        var grande = new MockMultipartFile("archivo", "grande.csv", "text/csv",
                new byte[(int) CsvArchivo.MAX_BYTES + 1]);

        ApiException error = assertThrows(ApiException.class,
                () -> CsvArchivo.leerUtf8(grande));

        assertEquals("CSV_INVALIDO", error.getCode());
        assertTrue(error.getMessage().contains("1 MB"));
    }

    @Test
    void rechazaBytesQueNoSonUtf8() {
        // "Cardiología" en Latin-1: la tilde queda como 0xED, invalido en UTF-8.
        byte[] latin1 = "nombre,requiere_pase\nCardiología,si\n"
                .getBytes(StandardCharsets.ISO_8859_1);
        var archivo = new MockMultipartFile("archivo", "a.csv", "text/csv", latin1);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> CsvArchivo.leerUtf8(archivo)
        );
        assertEquals("CSV_INVALIDO", exception.getCode());
    }

    @Test
    void parseaConComaYPuntoYComa() {
        String conComa = "nombre,requiere_pase\nCardiologia,si\n";
        String conPuntoYComa = "nombre;requiere_pase\nCardiologia;si\n";

        assertEquals(1, CsvArchivo.parsear(conComa, COLUMNAS).size());
        var filas = CsvArchivo.parsear(conPuntoYComa, COLUMNAS);
        assertEquals(1, filas.size());
        assertEquals("Cardiologia", filas.get(0).valor(0));
        assertEquals("si", filas.get(0).valor(1));
    }

    @Test
    void respetaCamposEntrecomilladosConComas() {
        String csv = "nombre,requiere_pase\n\"Cardiologia, general\",si\n";

        var filas = CsvArchivo.parsear(csv, COLUMNAS);

        assertEquals(1, filas.size());
        assertNull(filas.get(0).error());
        assertEquals("Cardiologia, general", filas.get(0).valor(0));
    }

    @Test
    void aceptaMarcaBomInicial() {
        String csv = "\uFEFFnombre,requiere_pase\nCardiologia,si\n";

        var filas = CsvArchivo.parsear(csv, COLUMNAS);

        assertEquals(1, filas.size());
        assertNull(filas.get(0).error());
    }

    @Test
    void rechazaContenidoVacio() {
        ApiException exception = assertThrows(
                ApiException.class,
                () -> CsvArchivo.parsear("   ", COLUMNAS)
        );
        assertEquals("CSV_INVALIDO", exception.getCode());
    }

    @Test
    void rechazaCabecerasIncorrectasFaltantesYAdicionales() {
        ApiException incorrecta = assertThrows(
                ApiException.class,
                () -> CsvArchivo.parsear("name,requiere_pase\nCardiologia,si\n", COLUMNAS)
        );
        assertEquals("CSV_INVALIDO", incorrecta.getCode());

        ApiException faltante = assertThrows(
                ApiException.class,
                () -> CsvArchivo.parsear("nombre\nCardiologia\n", COLUMNAS)
        );
        assertEquals("CSV_INVALIDO", faltante.getCode());

        ApiException adicional = assertThrows(
                ApiException.class,
                () -> CsvArchivo.parsear(
                        "nombre,requiere_pase,extra\nCardiologia,si,x\n",
                        COLUMNAS
                )
        );
        assertEquals("CSV_INVALIDO", adicional.getCode());
    }

    @Test
    void rechazaCabecerasDuplicadas() {
        ApiException exception = assertThrows(
                ApiException.class,
                () -> CsvArchivo.parsear(
                        "nombre,nombre\nCardiologia,si\n",
                        List.of("nombre")
                )
        );
        assertEquals("CSV_INVALIDO", exception.getCode());
    }

    @Test
    void marcaFilasConCantidadIncorrectaDeColumnas() {
        String csv = "nombre,requiere_pase\nCardiologia,si,extra\nPediatria\nNeurologia,no\n";

        var filas = CsvArchivo.parsear(csv, COLUMNAS);

        assertEquals(3, filas.size());
        assertTrue(filas.get(0).error().contains("exactamente 2 columnas"));
        assertTrue(filas.get(1).error().contains("exactamente 2 columnas"));
        assertNull(filas.get(2).error());
        assertEquals(4, filas.get(2).numero());
    }

    @Test
    void ignoraLineasVacias() {
        String csv = "nombre,requiere_pase\nCardiologia,si\n\n\nPediatria,no\n";

        var filas = CsvArchivo.parsear(csv, COLUMNAS);

        assertEquals(2, filas.size());
    }

    @Test
    void rechazaArchivosQueSuperanElMaximoDeFilas() {
        StringBuilder csv = new StringBuilder("nombre,requiere_pase\n");
        for (int i = 0; i < CsvArchivo.MAX_FILAS + 1; i++) {
            csv.append("Especialidad ").append(i).append(",si\n");
        }

        ApiException exception = assertThrows(
                ApiException.class,
                () -> CsvArchivo.parsear(csv.toString(), COLUMNAS)
        );
        assertEquals("CSV_INVALIDO", exception.getCode());
        assertTrue(exception.getMessage().contains("1000"));
    }

    /* ---------- Mensajes de cabecera que dicen que hacer ---------- */

    private static ApiException rechazoDeParseo(String csv) {
        ApiException error = assertThrows(
                ApiException.class, () -> CsvArchivo.parsear(csv, COLUMNAS));
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("CSV_INVALIDO", error.getCode());
        return error;
    }

    @Test
    void columnaQueSobraSeNombra() {
        ApiException error = rechazoDeParseo(
                "nombre,requiere_pase,extra\nCardiologia,si,x\n");

        assertEquals("El archivo no tiene las columnas esperadas. "
                + "Sobra la columna: extra. "
                + "Las columnas deben ser exactamente: nombre, requiere_pase.",
                error.getMessage());
    }

    @Test
    void columnaQueFaltaSeNombra() {
        ApiException error = rechazoDeParseo("nombre\nCardiologia\n");

        assertEquals("El archivo no tiene las columnas esperadas. "
                + "Falta la columna: requiere_pase. "
                + "Las columnas deben ser exactamente: nombre, requiere_pase.",
                error.getMessage());
    }

    @Test
    void faltanYSobranColumnasSeNombranLasDosListas() {
        ApiException error = rechazoDeParseo(
                "name,requiere_pase\nCardiologia,si\n");

        assertEquals("El archivo no tiene las columnas esperadas. "
                + "Falta la columna: nombre. "
                + "Sobra la columna: name. "
                + "Las columnas deben ser exactamente: nombre, requiere_pase.",
                error.getMessage());
    }

    @Test
    void variasColumnasQueFaltanYSobranVanEnPlural() {
        ApiException error = rechazoDeParseo("uno,dos\nA,B\n");

        assertEquals("El archivo no tiene las columnas esperadas. "
                + "Faltan las columnas: nombre, requiere_pase. "
                + "Sobran las columnas: uno, dos. "
                + "Las columnas deben ser exactamente: nombre, requiere_pase.",
                error.getMessage());
    }

    @Test
    void mayusculasSeExplicanConLosNombresExactos() {
        ApiException error = rechazoDeParseo(
                "Nombre;Requiere_pase\nCardiologia;si\n");

        assertEquals("El archivo no tiene las columnas esperadas. "
                + "Faltan las columnas: nombre, requiere_pase. "
                + "Sobran las columnas: Nombre, Requiere_pase. "
                + "Los nombres de las columnas se escriben en minúsculas. "
                + "Las columnas deben ser exactamente: nombre, requiere_pase.",
                error.getMessage());
    }

    @Test
    void cabeceraConEspaciosDiceQueColumnasTienenEspacios() {
        ApiException error = rechazoDeParseo(
                "nombre , requiere_pase\nCardiologia,si\n");

        assertEquals("La primera fila tiene columnas con espacios al principio "
                + "o al final: 'nombre ', ' requiere_pase'. "
                + "Borre esos espacios y vuelva a cargar el archivo.",
                error.getMessage());
    }

    @Test
    void cabeceraConEspaciosSoloAlPrincipioDeUnaColumna() {
        ApiException error = rechazoDeParseo(
                " nombre;requiere_pase\nCardiologia;si\n");

        assertEquals("La primera fila tiene columnas con espacios al principio "
                + "o al final: ' nombre'. "
                + "Borre esos espacios y vuelva a cargar el archivo.",
                error.getMessage());
    }

    @Test
    void puntoYComaDeMasAlFinalDiceQueHayUnaColumnaSinNombre() {
        ApiException error = rechazoDeParseo(
                "nombre;requiere_pase;\nCardiologia;si;\n");

        assertEquals("La primera fila tiene columnas sin nombre (posición 3). "
                + "Puede ser un separador de más al final: "
                + "bórrelo y vuelva a cargar el archivo.",
                error.getMessage());
    }

    @Test
    void comaDeMasAlFinalTambienDiceQueHayUnaColumnaSinNombre() {
        ApiException error = rechazoDeParseo(
                "nombre,requiere_pase,\nCardiologia,si,\n");

        assertEquals("La primera fila tiene columnas sin nombre (posición 3). "
                + "Puede ser un separador de más al final: "
                + "bórrelo y vuelva a cargar el archivo.",
                error.getMessage());
    }

    @Test
    void variasColumnasSinNombreVanEnPlural() {
        ApiException error = rechazoDeParseo(
                "nombre;requiere_pase;;\nCardiologia;si;;\n");

        assertEquals("La primera fila tiene columnas sin nombre (posiciones 3, 4). "
                + "Puede ser un separador de más al final: "
                + "bórrelo y vuelva a cargar el archivo.",
                error.getMessage());
    }

    @Test
    void columnaRepetidaSeNombra() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> CsvArchivo.parsear(
                        "nombre,nombre\nCardiologia,si\n", List.of("nombre")));

        assertEquals("La columna 'nombre' está repetida en la primera fila. "
                + "Cada columna debe aparecer una sola vez.",
                error.getMessage());
    }

    @Test
    void cabeceraConEspaciosYOtrosErroresInformaPrimeroLosEspacios() {
        ApiException error = rechazoDeParseo("nombre ,otra\nA,B\n");

        assertEquals("La primera fila tiene columnas con espacios al principio "
                + "o al final: 'nombre '. "
                + "Borre esos espacios y vuelva a cargar el archivo.",
                error.getMessage());
    }

    @Test
    void archivoQueNoEsUtf8SugiereGuardarloComoCsvUtf8() {
        byte[] latin1 = "nombre,requiere_pase\nCardiología,si\n"
                .getBytes(StandardCharsets.ISO_8859_1);
        var archivo = new MockMultipartFile("archivo", "a.csv", "text/csv", latin1);

        ApiException error = assertThrows(
                ApiException.class, () -> CsvArchivo.leerUtf8(archivo));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("CSV_INVALIDO", error.getCode());
        assertEquals("El archivo no está guardado con codificación UTF-8, "
                + "por eso las tildes y las eñes no se leen bien. "
                + "Guárdelo de nuevo como CSV UTF-8 (en Excel: Guardar como, "
                + "tipo CSV UTF-8 delimitado por comas) y vuelva a cargarlo.",
                error.getMessage());
    }

    private static final String MENSAJE_UTF16 =
            "El archivo está guardado como Unicode (UTF-16) y no se puede leer. "
                    + "Guárdelo de nuevo como CSV UTF-8 (en Excel: Guardar como, "
                    + "tipo CSV UTF-8 delimitado por comas) y vuelva a cargarlo.";

    private static ApiException rechazoDeLectura(byte[] bytes) {
        var archivo = new MockMultipartFile("archivo", "a.csv", "text/csv", bytes);
        ApiException error = assertThrows(
                ApiException.class, () -> CsvArchivo.leerUtf8(archivo));
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("CSV_INVALIDO", error.getCode());
        return error;
    }

    @Test
    void utf16ConMarcaBomLittleEndianSeDetecta() {
        byte[] texto = "nombre,requiere_pase\nCardiologia,si\n"
                .getBytes(StandardCharsets.UTF_16LE);
        byte[] bytes = new byte[texto.length + 2];
        bytes[0] = (byte) 0xFF;
        bytes[1] = (byte) 0xFE;
        System.arraycopy(texto, 0, bytes, 2, texto.length);

        assertEquals(MENSAJE_UTF16, rechazoDeLectura(bytes).getMessage());
    }

    @Test
    void utf16ConMarcaBomBigEndianSeDetecta() {
        byte[] texto = "nombre,requiere_pase\nCardiologia,si\n"
                .getBytes(StandardCharsets.UTF_16BE);
        byte[] bytes = new byte[texto.length + 2];
        bytes[0] = (byte) 0xFE;
        bytes[1] = (byte) 0xFF;
        System.arraycopy(texto, 0, bytes, 2, texto.length);

        assertEquals(MENSAJE_UTF16, rechazoDeLectura(bytes).getMessage());
    }

    @Test
    void utf16LittleEndianSinMarcaBomSeDetectaPorLosBytesNulos() {
        byte[] bytes = "nombre,requiere_pase\nCardiologia,si\n"
                .getBytes(StandardCharsets.UTF_16LE);

        assertEquals(MENSAJE_UTF16, rechazoDeLectura(bytes).getMessage());
    }

    @Test
    void utf16BigEndianSinMarcaBomSeDetectaPorLosBytesNulos() {
        byte[] bytes = "nombre,requiere_pase\nCardiologia,si\n"
                .getBytes(StandardCharsets.UTF_16BE);

        assertEquals(MENSAJE_UTF16, rechazoDeLectura(bytes).getMessage());
    }

    @Test
    void utf8ConMarcaBomSigueSiendoValido() {
        byte[] texto = "nombre,requiere_pase\nCardiología,si\n"
                .getBytes(StandardCharsets.UTF_8);
        byte[] bytes = new byte[texto.length + 3];
        bytes[0] = (byte) 0xEF;
        bytes[1] = (byte) 0xBB;
        bytes[2] = (byte) 0xBF;
        System.arraycopy(texto, 0, bytes, 3, texto.length);
        var archivo = new MockMultipartFile("archivo", "a.csv", "text/csv", bytes);

        assertTrue(CsvArchivo.leerUtf8(archivo).contains("Cardiología"));
    }
}
