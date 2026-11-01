package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class TurnoSemanalRepository {

    private final JdbcTemplate jdbcTemplate;

    public TurnoSemanalRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<CuentaMedica> bloquearMedico(Long idMedico) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.rol, c.habilitada,
                               p.nombre, p.apellido
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.id_cuenta = ?
                        FOR UPDATE OF c
                        """,
                        (rs, rowNum) -> new CuentaMedica(
                                rs.getLong("id_cuenta"),
                                rs.getString("rol"),
                                rs.getBoolean("habilitada"),
                                rs.getString("nombre"),
                                rs.getString("apellido")
                        ),
                        idMedico
                )
                .stream()
                .findFirst();
    }

    public Optional<Consultorio> bloquearConsultorio(Long idConsultorio) {
        return jdbcTemplate.query(
                        """
                        SELECT id_consultorio, nombre, ubicacion
                        FROM public.consultorio
                        WHERE id_consultorio = ?
                        FOR UPDATE
                        """,
                        (rs, rowNum) -> new Consultorio(
                                rs.getLong("id_consultorio"),
                                rs.getString("nombre"),
                                rs.getString("ubicacion")
                        ),
                        idConsultorio
                )
                .stream()
                .findFirst();
    }

    public Optional<Especialidad> buscarEspecialidadDelMedico(
            Long idMedico,
            Long idEspecialidad
    ) {
        return jdbcTemplate.query(
                        """
                        SELECT e.id_especialidad, e.nombre, e.requiere_pase
                        FROM public.medico_especialidad me
                        JOIN public.especialidad e
                          ON e.id_especialidad = me.id_especialidad
                        WHERE me.id_medico = ?
                          AND me.id_especialidad = ?
                        FOR KEY SHARE OF me, e
                        """,
                        (rs, rowNum) -> new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        idMedico,
                        idEspecialidad
                )
                .stream()
                .findFirst();
    }

    public List<NumeroExistente> buscarNumerosActivos(
            Long idMedico,
            Long idConsultorio,
            LocalDate desde,
            LocalDate hasta
    ) {
        return jdbcTemplate.query(
                """
                SELECT t.fecha, ts.id_medico, t.id_consultorio,
                       n.numero, n.hora_inicio, n.hora_fin
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.numero n ON n.id_turno = t.id_turno
                WHERE t.estado = 'ACTIVO'
                  AND t.fecha BETWEEN ? AND ?
                  AND (ts.id_medico = ? OR t.id_consultorio = ?)
                ORDER BY t.fecha, n.hora_inicio, n.numero
                """,
                (rs, rowNum) -> new NumeroExistente(
                        rs.getObject("fecha", LocalDate.class),
                        rs.getLong("id_medico"),
                        rs.getLong("id_consultorio"),
                        rs.getInt("numero"),
                        rs.getObject("hora_inicio", LocalTime.class),
                        rs.getObject("hora_fin", LocalTime.class)
                ),
                desde,
                hasta,
                idMedico,
                idConsultorio
        );
    }

    public Long crearPatron(
            Long idMedico,
            Long idEspecialidad,
            Long idConsultorio,
            Long idFuncionario,
            int diaSemana,
            LocalDate fechaInicio,
            LocalDate fechaFin
    ) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.turno_semanal
                    (id_medico, id_especialidad, id_consultorio,
                     id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                RETURNING id_turno_semanal
                """,
                Long.class,
                idMedico,
                idEspecialidad,
                idConsultorio,
                idFuncionario,
                diaSemana,
                fechaInicio,
                fechaFin
        );
    }

    public Long crearNumeroSemanal(
            Long idTurnoSemanal,
            int numero,
            LocalTime horaInicio,
            LocalTime horaFin
    ) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.numero_semanal
                    (id_turno_semanal, numero, hora_inicio, hora_fin)
                VALUES (?, ?, ?, ?)
                RETURNING id_numero_semanal
                """,
                Long.class,
                idTurnoSemanal,
                numero,
                horaInicio,
                horaFin
        );
    }

    public Long crearTurno(
            Long idTurnoSemanal,
            Long idConsultorio,
            LocalDate fecha
    ) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.turno
                    (id_turno_semanal, id_consultorio, fecha)
                VALUES (?, ?, ?)
                RETURNING id_turno
                """,
                Long.class,
                idTurnoSemanal,
                idConsultorio,
                fecha
        );
    }

    public void crearNumeros(
            Long idTurno,
            List<NumeroInstancia> numeros
    ) {
        jdbcTemplate.batchUpdate(
                """
                INSERT INTO public.numero
                    (id_turno, id_numero_semanal, numero,
                     hora_inicio, hora_fin)
                VALUES (?, ?, ?, ?, ?)
                """,
                numeros,
                numeros.size(),
                (statement, numero) -> {
                    statement.setLong(1, idTurno);
                    statement.setLong(2, numero.idNumeroSemanal());
                    statement.setInt(3, numero.numero());
                    statement.setObject(4, numero.horaInicio());
                    statement.setObject(5, numero.horaFin());
                }
        );
    }

    public record CuentaMedica(
            Long id,
            String rol,
            boolean habilitada,
            String nombre,
            String apellido
    ) {
    }

    public record NumeroExistente(
            LocalDate fecha,
            Long idMedico,
            Long idConsultorio,
            int numero,
            LocalTime horaInicio,
            LocalTime horaFin
    ) {
    }

    public record NumeroInstancia(
            Long idNumeroSemanal,
            int numero,
            LocalTime horaInicio,
            LocalTime horaFin
    ) {
    }

    /* ---------- RF-20: modificacion del consultorio ---------- */

    /**
     * Bloquea la configuracion semanal (FOR UPDATE) y devuelve sus datos.
     * Dos modificaciones del mismo patron se serializan con este bloqueo.
     */
    public Optional<PatronSemanal> bloquearPatron(Long idTurnoSemanal) {
        return jdbcTemplate.query(
                        """
                        SELECT id_turno_semanal, id_medico, id_especialidad,
                               id_consultorio, dia_semana,
                               fecha_inicio, fecha_fin
                        FROM public.turno_semanal
                        WHERE id_turno_semanal = ?
                        FOR UPDATE
                        """,
                        (rs, rowNum) -> new PatronSemanal(
                                rs.getLong("id_turno_semanal"),
                                rs.getLong("id_medico"),
                                rs.getLong("id_especialidad"),
                                rs.getLong("id_consultorio"),
                                rs.getInt("dia_semana"),
                                rs.getObject("fecha_inicio", LocalDate.class),
                                rs.getObject("fecha_fin", LocalDate.class)
                        ),
                        idTurnoSemanal
                )
                .stream()
                .findFirst();
    }

    /**
     * Fechas activas del patron desde hoy (inclusive), bloqueando las filas
     * de turno (FOR UPDATE). La agenda tambien bloquea la fila del turno al
     * reservar, asi que ninguna consulta nueva puede colarse mientras dure
     * la modificacion.
     */
    public List<LocalDate> bloquearFechasActivasDesde(
            Long idTurnoSemanal,
            LocalDate hoy
    ) {
        return jdbcTemplate.query(
                """
                SELECT fecha
                FROM public.turno
                WHERE id_turno_semanal = ?
                  AND fecha >= ?
                  AND estado = 'ACTIVO'
                ORDER BY fecha
                FOR UPDATE
                """,
                (rs, rowNum) -> rs.getObject("fecha", LocalDate.class),
                idTurnoSemanal,
                hoy
        );
    }

    /** Consultas AGENDADA en fechas del patron cuyo dia todavia no termino. */
    public int contarConsultasAgendadasDesde(
            Long idTurnoSemanal,
            LocalDate hoy
    ) {
        Integer cantidad = jdbcTemplate.queryForObject(
                """
                SELECT count(*)
                FROM public.consulta c
                JOIN public.numero n ON n.id_numero = c.id_numero
                JOIN public.turno t ON t.id_turno = n.id_turno
                WHERE t.id_turno_semanal = ?
                  AND t.fecha >= ?
                  AND c.estado = 'AGENDADA'
                """,
                Integer.class,
                idTurnoSemanal,
                hoy
        );
        return cantidad == null ? 0 : cantidad;
    }

    /** Numeros (horarios) de la configuracion semanal. */
    public List<NumeroInstancia> numerosDelPatron(Long idTurnoSemanal) {
        return jdbcTemplate.query(
                """
                SELECT id_numero_semanal, numero, hora_inicio, hora_fin
                FROM public.numero_semanal
                WHERE id_turno_semanal = ?
                ORDER BY numero
                """,
                (rs, rowNum) -> new NumeroInstancia(
                        rs.getLong("id_numero_semanal"),
                        rs.getInt("numero"),
                        rs.getObject("hora_inicio", LocalTime.class),
                        rs.getObject("hora_fin", LocalTime.class)
                ),
                idTurnoSemanal
        );
    }

    /**
     * Como buscarNumerosActivos pero excluyendo los turnos del propio
     * patron: sus horarios no cambian, no compiten consigo mismos.
     */
    public List<NumeroExistente> buscarNumerosActivosDeOtrosPatrones(
            Long idMedico,
            Long idConsultorio,
            LocalDate desde,
            LocalDate hasta,
            Long idPatronExcluido
    ) {
        return jdbcTemplate.query(
                """
                SELECT t.fecha, ts.id_medico, t.id_consultorio,
                       n.numero, n.hora_inicio, n.hora_fin
                FROM public.turno t
                JOIN public.turno_semanal ts
                  ON ts.id_turno_semanal = t.id_turno_semanal
                JOIN public.numero n ON n.id_turno = t.id_turno
                WHERE t.estado = 'ACTIVO'
                  AND t.fecha BETWEEN ? AND ?
                  AND (ts.id_medico = ? OR t.id_consultorio = ?)
                  AND ts.id_turno_semanal <> ?
                ORDER BY t.fecha, n.hora_inicio, n.numero
                """,
                (rs, rowNum) -> new NumeroExistente(
                        rs.getObject("fecha", LocalDate.class),
                        rs.getLong("id_medico"),
                        rs.getLong("id_consultorio"),
                        rs.getInt("numero"),
                        rs.getObject("hora_inicio", LocalTime.class),
                        rs.getObject("hora_fin", LocalTime.class)
                ),
                desde,
                hasta,
                idMedico,
                idConsultorio,
                idPatronExcluido
        );
    }

    /**
     * Aplica el consultorio nuevo a la configuracion y a los turnos de
     * fechas actuales y futuras (activos y suspendidos conservan su
     * estado). Las fechas pasadas no se tocan.
     */
    public void actualizarConsultorio(
            Long idTurnoSemanal,
            Long idConsultorio,
            LocalDate hoy
    ) {
        jdbcTemplate.update(
                """
                UPDATE public.turno_semanal
                SET id_consultorio = ?
                WHERE id_turno_semanal = ?
                """,
                idConsultorio,
                idTurnoSemanal
        );
        jdbcTemplate.update(
                """
                UPDATE public.turno
                SET id_consultorio = ?
                WHERE id_turno_semanal = ?
                  AND fecha >= ?
                """,
                idConsultorio,
                idTurnoSemanal,
                hoy
        );
    }

    public record PatronSemanal(
            Long id,
            Long idMedico,
            Long idEspecialidad,
            Long idConsultorio,
            int diaSemana,
            LocalDate fechaInicio,
            LocalDate fechaFin
    ) {
    }
}
