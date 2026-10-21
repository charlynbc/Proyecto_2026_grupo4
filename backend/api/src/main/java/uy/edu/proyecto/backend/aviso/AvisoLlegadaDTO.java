package uy.edu.proyecto.backend.aviso;

import java.time.LocalDate;
import java.time.OffsetDateTime;

public record AvisoLlegadaDTO(
        Long id,
        SocioRef socio,
        LocalDate fecha,
        OffsetDateTime registradaEn,
        FuncionarioRef registradaPor
) {
    public record SocioRef(String ci, String nombre, String apellido) {
    }

    public record FuncionarioRef(Long id, String nombre, String apellido) {
    }
}
