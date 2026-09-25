package uy.edu.proyecto.backend.usuario;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Email;

public record CrearUsuarioRequest(

        @NotBlank
        @Size(max = 100)
        String nombre,

        @NotBlank
        @Size(max = 20)
        String cedula,

        @NotBlank
        @Email
        @Size(max = 254)
        String email,

        @NotBlank
        String clave

) {
}