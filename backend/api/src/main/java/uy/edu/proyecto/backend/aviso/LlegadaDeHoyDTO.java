package uy.edu.proyecto.backend.aviso;

import java.time.OffsetDateTime;

/** La llegada de hoy de un socio: cuando se registro y quien la registro. */
public record LlegadaDeHoyDTO(
        OffsetDateTime registradaEn,
        AvisoLlegadaDTO.FuncionarioRef registradaPor
) {
}
