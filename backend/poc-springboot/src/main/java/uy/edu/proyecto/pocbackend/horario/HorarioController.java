package uy.edu.proyecto.pocbackend.horario;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import javax.sql.DataSource;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * GET /profesionales/{id}/horarios.
 *
 * Si hay un DataSource real disponible (perfil "postgres"), consulta la base
 * real via HorarioJdbcDao con el mismo criterio de
 * database/poc-sql/backend/08_horarios_disponibles.sql (horarios futuros de
 * los proximos 30 dias sin reserva activa). Si no hay DataSource, devuelve
 * una lista fija en memoria (mock).
 */
@RestController
public class HorarioController {

    private static final List<Horario> MOCK = List.of(
            new Horario(101L, 1L, OffsetDateTime.parse("2026-09-14T09:00:00-03:00"), OffsetDateTime.parse("2026-09-14T09:15:00-03:00")),
            new Horario(102L, 1L, OffsetDateTime.parse("2026-09-14T09:30:00-03:00"), OffsetDateTime.parse("2026-09-14T09:50:00-03:00")),
            new Horario(201L, 2L, OffsetDateTime.parse("2026-09-14T09:00:00-03:00"), OffsetDateTime.parse("2026-09-14T09:15:00-03:00")),
            new Horario(301L, 3L, OffsetDateTime.parse("2026-09-14T14:00:00-03:00"), OffsetDateTime.parse("2026-09-14T14:15:00-03:00")),
            new Horario(401L, 4L, OffsetDateTime.parse("2026-09-14T14:00:00-03:00"), OffsetDateTime.parse("2026-09-14T14:15:00-03:00"))
    );

    private final DataSource dataSource;

    @Autowired
    public HorarioController(Optional<DataSource> dataSource) {
        this.dataSource = dataSource.orElse(null);
    }

    @GetMapping("/profesionales/{id}/horarios")
    public List<Horario> listar(@PathVariable Long id) throws SQLException {
        if (dataSource == null) {
            return MOCK.stream()
                    .filter(h -> h.profesionalId().equals(id))
                    .collect(Collectors.toList());
        }

        OffsetDateTime ahora = OffsetDateTime.now();
        HorarioJdbcDao dao = new HorarioJdbcDao(dataSource);
        return dao.disponibles(id, ahora, ahora.plusDays(30));
    }
}

