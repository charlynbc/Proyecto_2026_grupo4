package uy.edu.proyecto.backend.reserva;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record CrearReservaRequest(

        @NotNull
        @Positive
        Long horarioId

) {
}
