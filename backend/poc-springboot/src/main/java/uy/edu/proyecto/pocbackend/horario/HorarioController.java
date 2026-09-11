package uy.edu.proyecto.pocbackend.horario;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.stream.Collectors;

/**
 * GET /profesionales/{id}/horarios.
 *
 * DATOS MOCK, igual que ProfesionalController: no hay conexion PostgreSQL
 * configurada. La consulta de referencia es
 * database/poc-sql/backend/08_horarios_disponibles.sql (horarios futuros sin
 * reserva activa).
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

    @GetMapping("/profesionales/{id}/horarios")
    public List<Horario> listar(@PathVariable Long id) {
        return MOCK.stream()
                .filter(h -> h.profesionalId().equals(id))
                .collect(Collectors.toList());
    }
}
