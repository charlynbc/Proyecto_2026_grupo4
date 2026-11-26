package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;

/**
 * Los IT no se saltean nunca: el CI falla si una prueba de integracion queda
 * omitida, y una omision que depende de la hora del dia hace que el mismo
 * codigo pase a una hora y falle a otra. Esta prueba no necesita base de datos:
 * lee el codigo fuente de los IT (la prueba corre desde backend/api).
 */
class ITsSinOmisionesPorHoraTest {

    private static final Path CARPETA = Path.of("src/test/java/uy/edu/proyecto/backend/integracion");

    private static final Pattern OMISION = Pattern.compile(
            "assumeTrue|assumeFalse|assumingThat|Assumptions|@Disabled|@EnabledIf|@DisabledIf|@EnabledOn|@DisabledOn");

    private static List<Path> itsDeLaCarpeta() throws IOException {
        try (Stream<Path> archivos = Files.list(CARPETA)) {
            return archivos.filter(a -> a.getFileName().toString().endsWith("IT.java")).sorted().toList();
        }
    }

    /** El codigo sin comentarios de linea ni de bloque, para no contar lo que solo se nombra. */
    private static String sinComentarios(Path archivo) throws IOException {
        return Files.readString(archivo)
                .replaceAll("(?s)/\\*.*?\\*/", "")
                .replaceAll("(?m)//.*$", "");
    }

    @Test
    void laCarpetaTieneLosITsQueSeEsperan() throws IOException {
        List<String> nombres = itsDeLaCarpeta().stream().map(a -> a.getFileName().toString()).toList();

        assertTrue(nombres.contains("ConsultasCancelableIT.java"), nombres.toString());
        assertTrue(nombres.contains("BaseIntegracionIT.java"), nombres.toString());
    }

    @Test
    void ningunITUsaAssumptionsNiDisabledNiEnabledIf() throws IOException {
        List<String> encontrados = new ArrayList<>();
        for (Path it : itsDeLaCarpeta()) {
            String[] lineas = sinComentarios(it).split("\n");
            for (int i = 0; i < lineas.length; i++) {
                if (OMISION.matcher(lineas[i]).find()) {
                    encontrados.add(it.getFileName() + ":" + (i + 1) + " " + lineas[i].trim());
                }
            }
        }

        assertEquals(List.of(), encontrados, "Estas lineas pueden omitir un IT segun la hora o el entorno");
    }

    @Test
    void consultasCancelableFijaElRelojYNoLeeLaHoraReal() throws IOException {
        String codigo = sinComentarios(CARPETA.resolve("ConsultasCancelableIT.java"));

        assertTrue(codigo.contains("reloj.fijar("), "El IT debe fijar el reloj de la aplicacion");
        assertFalse(codigo.contains("LocalDateTime.now("), "El IT no debe leer la hora real");
        assertFalse(codigo.contains("LocalTime.now("), "El IT no debe leer la hora real");
        assertFalse(codigo.contains("Instant.now("), "El IT no debe leer la hora real");
    }
}
