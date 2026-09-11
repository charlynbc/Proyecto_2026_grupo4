package uy.edu.proyecto.pocbackend.reserva;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * POST /reservas.
 *
 * DATOS MOCK en memoria (no hay conexion PostgreSQL configurada). La idea de
 * esta prueba es solamente mostrar como se manejaria el 409 Conflict cuando
 * el horario ya esta reservado, tal como lo evitaria en la base real
 * database/poc-sql/backend/09_reserva_alta.sql combinado con la validacion de
 * 08_horarios_disponibles.sql (que excluye horarios con reserva activa).
 *
 * OJO: esto no hace ninguna modificacion sobre una base remota, todo el
 * estado vive en este Set en memoria y se pierde al reiniciar la app.
 */
@RestController
public class ReservaController {

    private final Set<Long> horariosReservados = ConcurrentHashMap.newKeySet();
    private final AtomicLong secuenciaId = new AtomicLong(1);

    @PostMapping("/reservas")
    public ResponseEntity<Reserva> reservar(@RequestBody NuevaReservaRequest request) {
        boolean reservadoAhora = horariosReservados.add(request.horarioId());

        if (!reservadoAhora) {
            // El horario ya tenia una reserva activa (mock): 409 Conflict.
            return ResponseEntity.status(HttpStatus.CONFLICT).build();
        }

        Reserva reserva = new Reserva(
                secuenciaId.getAndIncrement(),
                request.usuarioId(),
                request.horarioId(),
                "ACTIVA",
                OffsetDateTime.now()
        );

        return ResponseEntity.status(HttpStatus.CREATED).body(reserva);
    }
}
