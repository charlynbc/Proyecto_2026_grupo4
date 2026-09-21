package uy.edu.proyecto.pocbackend.reserva;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Test unitario del circuito de conflicto de POST /reservas en modo mock
 * (sin DataSource, no necesita base real). Cubre el caso de
 * database/poc-sql/backend/09_reserva_alta.sql: no se puede reservar dos
 * veces el mismo horario.
 */
class ReservaControllerTest {

    @Test
    void segundaReservaDelMismoHorarioDaConflicto() throws Exception {
        ReservaController controller = new ReservaController(Optional.empty());

        ResponseEntity<Reserva> primera = controller.reservar(new NuevaReservaRequest(1L, 999L));
        assertEquals(HttpStatus.CREATED, primera.getStatusCode());

        ResponseEntity<Reserva> segunda = controller.reservar(new NuevaReservaRequest(2L, 999L));
        assertEquals(HttpStatus.CONFLICT, segunda.getStatusCode());
    }
}
