package uy.edu.proyecto.pocbackend.reserva;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * POST /reservas, PATCH /reservas/{id}/cancelacion y GET /mis-reservas.
 *
 * Si hay un DataSource real disponible (perfil "postgres"), usa
 * ReservaJdbcDao contra la base real (database/poc-sql/backend/09_reserva_alta.sql,
 * 10_reserva_cancelar.sql y 11_reservas_usuario.sql). Sin DataSource, cae a
 * un mock en memoria (Set de horarios reservados, se pierde al reiniciar).
 */
@RestController
public class ReservaController {

    private final Set<Long> horariosReservados = ConcurrentHashMap.newKeySet();
    private final AtomicLong secuenciaId = new AtomicLong(1);
    private final DataSource dataSource;

    @Autowired
    public ReservaController(Optional<DataSource> dataSource) {
        this.dataSource = dataSource.orElse(null);
    }

    @PostMapping("/reservas")
    public ResponseEntity<Reserva> reservar(@RequestBody NuevaReservaRequest request) throws SQLException {
        if (dataSource != null) {
            Optional<Reserva> creada = new ReservaJdbcDao(dataSource).crear(request.usuarioId(), request.horarioId());
            return creada.map(r -> ResponseEntity.status(HttpStatus.CREATED).body(r))
                    .orElseGet(() -> ResponseEntity.status(HttpStatus.CONFLICT).build());
        }

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

    @PatchMapping("/reservas/{id}/cancelacion")
    public ResponseEntity<Reserva> cancelar(@PathVariable Long id, @RequestBody CancelacionRequest request) throws SQLException {
        if (dataSource == null) {
            // Sin base real no hay estado persistente de reservas por id para cancelar.
            return ResponseEntity.status(HttpStatus.NOT_IMPLEMENTED).build();
        }

        Optional<Reserva> cancelada = new ReservaJdbcDao(dataSource).cancelar(id, request.usuarioId());
        return cancelada.map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).build());
    }

    @GetMapping("/mis-reservas")
    public ResponseEntity<List<Reserva>> misReservas(@RequestParam Long usuarioId) throws SQLException {
        if (dataSource == null) {
            return ResponseEntity.ok(List.of());
        }

        return ResponseEntity.ok(new ReservaJdbcDao(dataSource).listarPorUsuario(usuarioId));
    }
}

