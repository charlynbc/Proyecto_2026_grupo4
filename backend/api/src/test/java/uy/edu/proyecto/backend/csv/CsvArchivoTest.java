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
}
