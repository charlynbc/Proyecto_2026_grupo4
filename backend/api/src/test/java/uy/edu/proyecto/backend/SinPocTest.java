package uy.edu.proyecto.backend;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;

class SinPocTest {

    private static final Path MAIN = Path.of("src", "main");

    @Test
    void ningunCodigoNiConsultaDeProduccionUsaElEsquemaPoc() throws IOException {
        List<String> culpables;
        try (Stream<Path> archivos = Files.walk(MAIN)) {
            culpables = archivos
                    .filter(Files::isRegularFile)
                    .filter(p -> !p.toString().endsWith(".class"))
                    .filter(p -> contiene(p, "\"POC\"") || contiene(p, "POC."))
                    .map(Path::toString)
                    .toList();
        }

        assertTrue(culpables.isEmpty(), "Referencias a POC: " + culpables);
    }

    @Test
    void noQuedanClasesDeLosEndpointsObsoletos() throws IOException {
        List<String> obsoletos = List.of(
                "RegistroController",
                "ReservaController",
                "ReservaConsultaController",
                "ProfesionalController",
                "UsuarioRepository",
                "RefreshTokenRepository"
        );
        try (Stream<Path> archivos = Files.walk(MAIN)) {
            List<String> presentes = archivos
                    .map(p -> p.getFileName().toString())
                    .filter(nombre -> obsoletos.stream()
                            .anyMatch(o -> nombre.equals(o + ".java")))
                    .toList();
            assertTrue(presentes.isEmpty(), "Siguen presentes: " + presentes);
        }
    }

    private static boolean contiene(Path archivo, String texto) {
        try {
            return Files.readString(archivo).contains(texto);
        } catch (IOException exception) {
            return false;
        }
    }
}
