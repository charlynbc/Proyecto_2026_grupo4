package uy.edu.proyecto.backend.usuario;

import java.util.List;

public record UsuarioCuentaPageResponse(
        List<UsuarioCuentaDTO> items,
        int page,
        int size,
        long total
) {
}
