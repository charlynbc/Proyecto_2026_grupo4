package uy.edu.proyecto.backend.notificacion;

public record ReservaCreadaEvent(

        Long usuarioId,
        Long reservaId,
        Long horarioId

) {
}
