package uy.edu.proyecto.backend.estadistica;

import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

final class IdFiltroEstadistico {
    private IdFiltroEstadistico() {}

    static Long resolver(String solicitado, String campo) {
        if (solicitado == null || solicitado.isBlank()) {
            return null;
        }
        try {
            long id = Long.parseLong(solicitado.trim());
            if (id > 0) {
                return id;
            }
        } catch (NumberFormatException ignored) {
            // Se responde igual que para cero o negativo.
        }
        throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                campo + " debe ser un identificador positivo");
    }
}
