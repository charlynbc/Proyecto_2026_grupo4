package uy.edu.proyecto.backend.agenda;

import java.util.List;

public record DisponibilidadResponse(
        List<NumeroDisponibleDTO> items
) {
}
