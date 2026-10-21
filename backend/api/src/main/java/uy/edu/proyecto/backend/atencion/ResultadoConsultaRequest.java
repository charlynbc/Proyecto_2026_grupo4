package uy.edu.proyecto.backend.atencion;

import java.util.List;

public record ResultadoConsultaRequest(
        String resultado,
        String afeccion,
        String tratamiento,
        String observaciones,
        List<PaseNuevoRequest> pases
) {
    public record PaseNuevoRequest(
            Long especialidadDestinoId,
            Integer vigenciaDias
    ) {
    }
}
