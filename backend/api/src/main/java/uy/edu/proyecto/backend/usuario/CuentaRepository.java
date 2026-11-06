package uy.edu.proyecto.backend.usuario;

import java.time.LocalDate;
import java.time.OffsetDateTime;
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

    /** Lectura sin bloqueo, para la previsualizacion de cargas masivas. */
    public Optional<PersonaRegistrada> buscarPersona(String ci) {
        return jdbcTemplate.query(
                        """
                        SELECT ci, nombre, apellido, fecha_nacimiento
                        FROM public.persona
                        WHERE ci = ?
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

    /* ---------- Correccion administrativa (RF-38) ---------- */

    /**
     * Bloquea la fila de la cuenta (FOR UPDATE) y devuelve la cuenta con su
     * persona, cualquiera sea su estado: el administrador tambien corrige
     * datos de cuentas inactivadas o pendientes de primer ingreso.
     */
    public Optional<CuentaCompleta> buscarCuentaCompleta(long idCuenta) {
        return consultarCuentaCompleta(idCuenta, false);
    }

    public Optional<CuentaCompleta> bloquearCuentaCompleta(long idCuenta) {
        return consultarCuentaCompleta(idCuenta, true);
    }

    private Optional<CuentaCompleta> consultarCuentaCompleta(
            long idCuenta, boolean bloquear) {
        String sql = """
                        SELECT c.id_cuenta, c.ci, p.nombre, p.apellido,
                               p.fecha_nacimiento, c.rol, c.correo,
                               c.telefono_1, c.telefono_2, c.direccion,
                               c.habilitada, c.primer_ingreso_completado
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.id_cuenta = ?
                        """ + (bloquear ? " FOR UPDATE OF c, p" : "");
        return jdbcTemplate.query(
                        sql,
                        (rs, rowNum) -> new CuentaCompleta(
                                rs.getLong("id_cuenta"),
                                rs.getString("ci"),
                                rs.getString("nombre"),
                                rs.getString("apellido"),
                                rs.getObject("fecha_nacimiento", LocalDate.class),
                                rs.getString("rol"),
                                rs.getString("correo"),
                                rs.getString("telefono_1"),
                                rs.getString("telefono_2"),
                                rs.getString("direccion"),
                                rs.getBoolean("habilitada"),
                                rs.getBoolean("primer_ingreso_completado")
                        ),
                        idCuenta
                )
                .stream()
                .findFirst();
    }

    public boolean existePersona(String ci) {
        return Boolean.TRUE.equals(
                jdbcTemplate.queryForObject(
                        "SELECT EXISTS (SELECT 1 FROM public.persona WHERE ci = ?)",
                        Boolean.class,
                        ci
                )
        );
    }

    /**
     * Actualiza los datos de la persona; el cambio de CI propaga a todas sus
     * cuentas por la FK ON UPDATE CASCADE (RF-38: la correccion vale para
     * todas las cuentas de la misma persona).
     */
    public void actualizarPersona(
            String ciActual,
            String ciNueva,
            String nombre,
            String apellido,
            LocalDate fechaNacimiento
    ) {
        jdbcTemplate.update(
                """
                UPDATE public.persona
                SET ci = ?, nombre = ?, apellido = ?, fecha_nacimiento = ?
                WHERE ci = ?
                """,
                ciNueva,
                nombre,
                apellido,
                fechaNacimiento,
                ciActual
        );
    }

    public void actualizarContactoCuenta(
            long idCuenta,
            String correo,
            String telefono1,
            String telefono2,
            String direccion
    ) {
        jdbcTemplate.update(
                """
                UPDATE public.cuenta
                SET correo = ?,
                    telefono_1 = ?,
                    telefono_2 = ?,
                    direccion = ?
                WHERE id_cuenta = ?
                """,
                correo,
                telefono1,
                telefono2,
                direccion,
                idCuenta
        );
    }

    public List<Long> especialidadesDelMedico(long idMedico) {
        return jdbcTemplate.query(
                """
                SELECT id_especialidad
                FROM public.medico_especialidad
                WHERE id_medico = ?
                ORDER BY id_especialidad
                """,
                (rs, rowNum) -> rs.getLong("id_especialidad"),
                idMedico
        );
    }

    public void eliminarEspecialidadDelMedico(long idMedico, long idEspecialidad) {
        jdbcTemplate.update(
                """
                DELETE FROM public.medico_especialidad
                WHERE id_medico = ? AND id_especialidad = ?
                """,
                idMedico,
                idEspecialidad
        );
    }

    /**
     * Turnos activos del medico en la especialidad: turnos semanales cuya
     * vigencia todavia no termino (RF-38).
     */
    public boolean medicoTieneTurnosVigentesEnEspecialidad(
            long idMedico,
            long idEspecialidad,
            LocalDate hoy
    ) {
        return Boolean.TRUE.equals(
                jdbcTemplate.queryForObject(
                        """
                        SELECT EXISTS (
                            SELECT 1
                            FROM public.turno_semanal
                            WHERE id_medico = ?
                              AND id_especialidad = ?
                              AND fecha_fin >= ?
                        )
                        """,
                        Boolean.class,
                        idMedico,
                        idEspecialidad,
                        hoy
                )
        );
    }

    /**
     * Consultas futuras del medico en la especialidad: agendadas cuyo dia
     * todavia no termino (RF-38).
     */
    public boolean medicoTieneConsultasFuturasEnEspecialidad(
            long idMedico,
            long idEspecialidad,
            LocalDate hoy
    ) {
        return Boolean.TRUE.equals(
                jdbcTemplate.queryForObject(
                        """
                        SELECT EXISTS (
                            SELECT 1
                            FROM public.consulta c
                            JOIN public.numero n ON n.id_numero = c.id_numero
                            JOIN public.turno t ON t.id_turno = n.id_turno
                            JOIN public.turno_semanal ts
                                ON ts.id_turno_semanal = t.id_turno_semanal
                            WHERE ts.id_medico = ?
                              AND ts.id_especialidad = ?
                              AND c.estado = 'AGENDADA'
                              AND t.fecha >= ?
                        )
                        """,
                        Boolean.class,
                        idMedico,
                        idEspecialidad,
                        hoy
                )
        );
    }

    /* ---------- Inactivacion y reactivacion de empleados (RF-45) ---------- */

    /**
     * Bloquea la fila de la cuenta (FOR UPDATE) y devuelve su estado con los
     * datos de la persona, cualquiera sea su estado.
     */
    public Optional<CuentaEstado> bloquearCuentaParaEstado(long idCuenta) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.ci, p.nombre, p.apellido, c.rol,
                               c.habilitada, c.ultimo_inactivador,
                               c.ultima_inactivacion_en, c.ultimo_reactivador,
                               c.ultima_reactivacion_en
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.id_cuenta = ?
                        FOR UPDATE OF c
                        """,
                        (rs, rowNum) -> new CuentaEstado(
                                rs.getLong("id_cuenta"),
                                rs.getString("ci"),
                                rs.getString("nombre"),
                                rs.getString("apellido"),
                                rs.getString("rol"),
                                rs.getBoolean("habilitada"),
                                rs.getObject("ultima_inactivacion_en", OffsetDateTime.class),
                                (Long) rs.getObject("ultimo_inactivador"),
                                rs.getObject("ultima_reactivacion_en", OffsetDateTime.class),
                                (Long) rs.getObject("ultimo_reactivador")
                        ),
                        idCuenta
                )
                .stream()
                .findFirst();
    }

    /**
     * Marca la cuenta como inactiva registrando quien lo hizo y cuando.
     * La condicion habilitada = TRUE evita pisar una inactivacion
     * concurrente; devuelve cuantas filas se actualizaron.
     */
    public int inactivarCuenta(long idCuenta, long idAdministrador) {
        return jdbcTemplate.update(
                """
                UPDATE public.cuenta
                SET habilitada = FALSE,
                    ultimo_inactivador = ?,
                    ultima_inactivacion_en = CURRENT_TIMESTAMP
                WHERE id_cuenta = ?
                  AND habilitada = TRUE
                """,
                idAdministrador,
                idCuenta
        );
    }

    /**
     * Marca la cuenta como habilitada registrando quien lo hizo y cuando.
     * La condicion habilitada = FALSE evita pisar una reactivacion
     * concurrente; el indice uq_cuenta_empleado_habilitado_ci rechaza una
     * segunda cuenta de empleado habilitada para la misma CI.
     */
    public int reactivarCuenta(long idCuenta, long idAdministrador) {
        return jdbcTemplate.update(
                """
                UPDATE public.cuenta
                SET habilitada = TRUE,
                    ultimo_reactivador = ?,
                    ultima_reactivacion_en = CURRENT_TIMESTAMP
                WHERE id_cuenta = ?
                  AND habilitada = FALSE
                """,
                idAdministrador,
                idCuenta
        );
    }

    /**
     * Existe otra cuenta de empleado habilitada (incluye pendientes de
     * primer ingreso) para la misma CI (RF-45: impide la reactivacion).
     */
    public boolean existeOtraCuentaEmpleadoHabilitada(String ci, long idCuenta) {
        return Boolean.TRUE.equals(
                jdbcTemplate.queryForObject(
                        """
                        SELECT EXISTS (
                            SELECT 1 FROM public.cuenta
                            WHERE ci = ?
                              AND id_cuenta <> ?
                              AND rol IN ('FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR')
                              AND habilitada = TRUE
                        )
                        """,
                        Boolean.class,
                        ci,
                        idCuenta
                )
        );
    }

    /**
     * Fechas activas de turnos del medico cuyo dia todavia no termino
     * (RF-45: impiden la inactivacion; primero se suspenden por RF-14).
     */
    public boolean medicoTieneFechasActivasDesde(long idMedico, LocalDate hoy) {
        return Boolean.TRUE.equals(
                jdbcTemplate.queryForObject(
                        """
                        SELECT EXISTS (
                            SELECT 1
                            FROM public.turno t
                            JOIN public.turno_semanal ts
                                ON ts.id_turno_semanal = t.id_turno_semanal
                            WHERE ts.id_medico = ?
                              AND t.estado = 'ACTIVO'
                              AND t.fecha >= ?
                        )
                        """,
                        Boolean.class,
                        idMedico,
                        hoy
                )
        );
    }

    /**
     * Consultas agendadas del medico cuyo dia todavia no termino
     * (RF-45: impiden la inactivacion).
     */
    public boolean medicoTieneConsultasAgendadasDesde(long idMedico, LocalDate hoy) {
        return Boolean.TRUE.equals(
                jdbcTemplate.queryForObject(
                        """
                        SELECT EXISTS (
                            SELECT 1
                            FROM public.consulta c
                            JOIN public.numero n ON n.id_numero = c.id_numero
                            JOIN public.turno t ON t.id_turno = n.id_turno
                            JOIN public.turno_semanal ts
                                ON ts.id_turno_semanal = t.id_turno_semanal
                            WHERE ts.id_medico = ?
                              AND c.estado = 'AGENDADA'
                              AND t.fecha >= ?
                        )
                        """,
                        Boolean.class,
                        idMedico,
                        hoy
                )
        );
    }

    public record PersonaRegistrada(
            String ci,
            String nombre,
            String apellido,
            LocalDate fechaNacimiento
    ) {
    }

    public record CuentaCompleta(
            long id,
            String ci,
            String nombre,
            String apellido,
            LocalDate fechaNacimiento,
            String rol,
            String correo,
            String telefono1,
            String telefono2,
            String direccion,
            boolean habilitada,
            boolean primerIngresoCompletado
    ) {
    }

    public record CuentaEstado(
            long id,
            String ci,
            String nombre,
            String apellido,
            String rol,
            boolean habilitada,
            OffsetDateTime ultimaInactivacionEn,
            Long ultimoInactivador,
            OffsetDateTime ultimaReactivacionEn,
            Long ultimoReactivador
    ) {
    }
}
