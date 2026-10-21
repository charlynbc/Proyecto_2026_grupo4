package uy.edu.proyecto.backend.consultorio;

import java.util.List;

public class ConsultorioCsvPrevisualizador {

    private final ConsultorioCsvParser parser;
    private final ConsultorioCsvValidador validador;

    public ConsultorioCsvPrevisualizador() {
        this.parser = new ConsultorioCsvParser();
        this.validador = new ConsultorioCsvValidador();
    }

    public record Resultado(
            int total,
            int validas,
            int invalidas,
            List<ConsultorioCsvValidador.ResultadoFila> filas,
            List<ConsultorioCsvValidador.ResultadoFila> errores
    ) {
    }

    public Resultado previsualizar(String contenido) {
        var filasLeidas = parser.leer(contenido);
        var filasValidadas = validador.validar(filasLeidas);

        var errores = filasValidadas.stream()
                .filter(fila -> !fila.valida())
                .toList();

        int total = filasValidadas.size();
        int invalidas = errores.size();
        int validas = total - invalidas;

        return new Resultado(
                total,
                validas,
                invalidas,
                List.copyOf(filasValidadas),
                errores
        );
    }
}
