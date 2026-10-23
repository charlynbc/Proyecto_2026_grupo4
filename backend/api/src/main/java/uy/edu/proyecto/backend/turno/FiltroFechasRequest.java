package uy.edu.proyecto.backend.turno;

public record FiltroFechasRequest(
        Long medicoId,
        Long especialidadId,
        String fechaDesde,
        String fechaHasta
) {
}
