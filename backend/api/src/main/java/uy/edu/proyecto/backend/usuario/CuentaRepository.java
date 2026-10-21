package uy.edu.proyecto.backend.usuario;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CuentaRepository {

    private final JdbcTemplate jdbcTemplate;

    public CuentaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void crearPersonaSiNoExiste(
            String ci,
            String nombre,
            String apellido,
            LocalDate fechaNacimiento
    ) {
        jdbcTemplate.update(
                """
                INSERT INTO public.persona (ci, nombre, apellido, fecha_nacimiento)
                VALUES (?, ?, ?, ?)
                ON CONFLICT (ci) DO NOTHING
                """,
                ci,
                nombre,
                apellido,
                fechaNacimiento
        );
    }

    public Optional<PersonaRegistrada> buscarPersonaParaActualizar(String ci) {
        return jdbcTemplate.query(
                        """
                        SELECT ci, nombre, apellido, fecha_nacimiento
                        FROM public.persona
                        WHERE ci = ?
                        FOR UPDATE
                        """,
                        (rs, rowNum) -> new PersonaRegistrada(
                                rs.getString("ci"),
                                rs.getString("nombre"),
                                rs.getString("apellido"),
                                rs.getObject("fecha_nacimiento", LocalDate.class)
                        ),
                        ci
                )
                .stream()
                .findFirst();
    }

    public boolean existeCuentaSocio(String ci) {
        return existeCuenta(
                """
                SELECT EXISTS (
                    SELECT 1 FROM public.cuenta
                    WHERE ci = ? AND rol = 'SOCIO'
                )
                """,
                ci
        );
    }

    public boolean existeCuentaEmpleadoHabilitada(String ci) {
        return existeCuenta(
                """
                SELECT EXISTS (
                    SELECT 1 FROM public.cuenta
                    WHERE ci = ?
                      AND rol IN ('FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR')
                      AND habilitada = TRUE
                )
                """,
                ci
        );
    }

    public List<Long> especialidadesExistentes(List<Long> ids) {
        if (ids.isEmpty()) {
            return List.of();
        }

        String placeholders = ids.stream()
                .map(ignored -> "?")
                .collect(Collectors.joining(", "));

        return jdbcTemplate.query(
                """
                SELECT id_especialidad
                FROM public.especialidad
                WHERE id_especialidad IN (%s)
                FOR KEY SHARE
                """.formatted(placeholders),
                (rs, rowNum) -> rs.getLong("id_especialidad"),
                ids.toArray()
        );
    }

    public Long crearCuenta(
            String ci,
            String rol,
            String correo,
            String telefono1,
            String telefono2,
            String direccion
    ) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.cuenta
                    (ci, rol, correo, telefono_1, telefono_2, direccion)
                VALUES (?, ?, ?, ?, ?, ?)
                RETURNING id_cuenta
                """,
                Long.class,
                ci,
                rol,
                correo,
                telefono1,
                telefono2,
                direccion
        );
    }

    public void asociarEspecialidades(Long idMedico, List<Long> ids) {
        jdbcTemplate.batchUpdate(
                """
                INSERT INTO public.medico_especialidad
                    (id_medico, id_especialidad)
                VALUES (?, ?)
                """,
                ids,
                ids.size(),
                (statement, idEspecialidad) -> {
                    statement.setLong(1, idMedico);
                    statement.setLong(2, idEspecialidad);
                }
        );
    }

    private boolean existeCuenta(String sql, String ci) {
        return Boolean.TRUE.equals(
                jdbcTemplate.queryForObject(sql, Boolean.class, ci)
        );
    }

    public record PersonaRegistrada(
            String ci,
            String nombre,
            String apellido,
            LocalDate fechaNacimiento
    ) {
    }
}
