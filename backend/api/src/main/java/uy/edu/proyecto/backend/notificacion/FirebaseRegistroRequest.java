package uy.edu.proyecto.backend.notificacion;

import jakarta.validation.constraints.NotBlank;

public record FirebaseRegistroRequest(

        @NotBlank
        String fid

) {
}
