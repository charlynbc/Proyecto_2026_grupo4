package uy.edu.proyecto.backend.aviso;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import uy.edu.proyecto.backend.agenda.ConsultaDTO;
import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;

@Repository
public class AvisoLlegadaRepository {

    private final JdbcTemplate jdbcTemplate;

    public AvisoLlegadaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<Socio> bloquearSocioHabilitado(String ci) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.ci, p.nombre, p.apellido
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.ci = ?
                          AND c.rol = 'SOCIO'
                          AND c.habilitada = TRUE
                        FOR UPDATE OF c
                        """,
                        (rs, rowNum) -> new Socio(
                                rs.getLong("id_cuenta"),
                                rs.getString("ci"),
                                rs.getString("nombre"),
                                rs.getString("apellido")
                        ),
                        ci
                )
                .stream()
                .findFirst();
    }

    public Optional<Socio> buscarSocioHabilitado(String ci) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.ci, p.nombre, p.apellido
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.ci = ?
                          AND c.rol = 'SOCIO'
                          AND c.habilitada = TRUE
                        """,
                        (rs, rowNum) -> new Socio(
                                rs.getLong("id_cuenta"),
                                rs.getString("ci"),
                                rs.getString("nombre"),
                                rs.getString("apellido")
                        ),
                        ci
                )
                .stream()
                .findFirst();
    }

    public Optional<Funcionario> buscarFuncionarioActivo(Long id) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.ci, p.nombre, p.apellido
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.id_cuenta = ?
                          AND c.rol = 'FUNCIONARIO'
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = TRUE
                        """,
                        (rs, rowNum) -> new Funcionario(
                                rs.getLong("id_cuenta"),
                                rs.getString("ci"),
                                rs.getString("nombre"),
                                rs.getString("apellido")
                        ),
                        id
                )
                .stream()
                .findFirst();
    }

    public Optional<AvisoLlegadaDTO> buscarAviso(Long socioId, LocalDate fecha) {
        return jdbcTemplate.query(
                        """
                        SELECT aviso.id_aviso_llegada, aviso.fecha,
                               aviso.registrada_en,
                               socio.ci AS socio_ci,
                               socio_persona.nombre AS socio_nombre,
                               socio_persona.apellido AS socio_apellido,
                               funcionario.id_cuenta AS funcionario_id,
                               funcionario_persona.nombre AS funcionario_nombre,
                               funcionario_persona.apellido AS funcionario_apellido
                        FROM public.aviso_llegada aviso
                        JOIN public.cuenta socio ON socio.id_cuenta = aviso.id_socio
                        JOIN public.persona socio_persona
                          ON socio_persona.ci = socio.ci
                        JOIN public.cuenta funcionario
                          ON funcionario.id_cuenta = aviso.id_funcionario
                        JOIN public.persona funcionario_persona
                          ON funcionario_persona.ci = funcionario.ci
                        WHERE aviso.id_socio = ? AND aviso.fecha = ?
                        """,
                        (rs, rowNum) -> new AvisoLlegadaDTO(
                                rs.getLong("id_aviso_llegada"),
                                new AvisoLlegadaDTO.SocioRef(
                                        rs.getString("socio_ci"),
                                        rs.getString("socio_nombre"),
                                        rs.getString("socio_apellido")
                                ),
                                rs.getObject("fecha", LocalDate.class),
                                rs.getObject(
                                        "registrada_en",
                                        OffsetDateTime.class
                                ),
                                new AvisoLlegadaDTO.FuncionarioRef(
                                        rs.getLong("funcionario_id"),
                                        rs.getString("funcionario_nombre"),
                                        rs.getString("funcionario_apellido")
                                )
                        ),
                        socioId,
                        fecha
                )
                .stream()
                .findFirst();
    }

    public List<ConsultaDTO> listarConsultasAgendadas(
            String ci,
            LocalDate fecha
    ) {
        return jdbcTemplate.query(
                """
                SELECT consulta.id_consulta, consulta.estado,
                       consulta.id_pase, consulta.agendada_en,
                       consulta.cancelada_en, consulta.motivo_cancelacion,
                       turno.fecha, numero.numero,
                       numero.hora_inicio, numero.hora_fin,
                       semanal.id_medico, medico_persona.nombre AS medico_nombre,
                       medico_persona.apellido AS medico_apellido,
                       especialidad.id_especialidad,
                       especialidad.nombre AS especialidad_nombre,
                       especialidad.requiere_pase,
                       consultorio.id_consultorio,
                       consultorio.nombre AS consultorio_nombre,
                       consultorio.ubicacion AS consultorio_ubicacion
                FROM public.consulta consulta
                JOIN public.cuenta socio ON socio.id_cuenta = consulta.id_socio
                JOIN public.numero numero ON numero.id_numero = consulta.id_numero
                JOIN public.turno turno ON turno.id_turno = numero.id_turno
                JOIN public.turno_semanal semanal
                  ON semanal.id_turno_semanal = turno.id_turno_semanal
                JOIN public.cuenta medico ON medico.id_cuenta = semanal.id_medico
                JOIN public.persona medico_persona
                  ON medico_persona.ci = medico.ci
                JOIN public.especialidad especialidad
                  ON especialidad.id_especialidad = semanal.id_especialidad
                JOIN public.consultorio consultorio
                  ON consultorio.id_consultorio = turno.id_consultorio
                WHERE socio.ci = ?
                  AND socio.rol = 'SOCIO'
                  AND consulta.estado = 'AGENDADA'
                  AND turno.fecha = ?
                ORDER BY numero.hora_inicio, consulta.id_consulta
                """,
                (rs, rowNum) -> new ConsultaDTO(
                        rs.getLong("id_consulta"),
                        rs.getString("estado"),
                        rs.getObject("fecha", LocalDate.class),
                        rs.getInt("numero"),
                        rs.getObject("hora_inicio", LocalTime.class).toString(),
                        rs.getObject("hora_fin", LocalTime.class).toString(),
                        new ConsultaDTO.MedicoRef(
                                rs.getLong("id_medico"),
                                rs.getString("medico_nombre"),
                                rs.getString("medico_apellido")
                        ),
                        new Especialidad(
                                rs.getLong("id_especialidad"),
                                rs.getString("especialidad_nombre"),
                                rs.getBoolean("requiere_pase")
                        ),
                        new Consultorio(
                                rs.getLong("id_consultorio"),
                                rs.getString("consultorio_nombre"),
                                rs.getString("consultorio_ubicacion")
                        ),
                        (Long) rs.getObject("id_pase"),
                        rs.getObject("agendada_en", OffsetDateTime.class),
                        rs.getObject("cancelada_en", OffsetDateTime.class),
                        rs.getString("motivo_cancelacion")
                ),
                ci,
                fecha
        );
    }

    public boolean socioTieneConsultaAgendadaHoy(Long socioId, LocalDate fecha) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.consulta consulta
                    JOIN public.numero numero ON numero.id_numero = consulta.id_numero
                    JOIN public.turno turno ON turno.id_turno = numero.id_turno
                    WHERE consulta.id_socio = ?
                      AND consulta.estado = 'AGENDADA'
                      AND turno.fecha = ?
                )
                """,
                Boolean.class,
                socioId,
                fecha
        ));
    }

    public Optional<AvisoLlegadaDTO> crearSiNoExiste(
            Socio socio,
            Funcionario funcionario,
            LocalDate fecha
    ) {
        return jdbcTemplate.query(
                        """
                        INSERT INTO public.aviso_llegada
                            (id_socio, id_funcionario, fecha)
                        VALUES (?, ?, ?)
                        ON CONFLICT (id_socio, fecha) DO NOTHING
                        RETURNING id_aviso_llegada, fecha, registrada_en
                        """,
                        (rs, rowNum) -> new AvisoLlegadaDTO(
                                rs.getLong("id_aviso_llegada"),
                                new AvisoLlegadaDTO.SocioRef(
                                        socio.ci(),
                                        socio.nombre(),
                                        socio.apellido()
                                ),
                                rs.getObject("fecha", LocalDate.class),
                                rs.getObject(
                                        "registrada_en",
                                        OffsetDateTime.class
                                ),
                                new AvisoLlegadaDTO.FuncionarioRef(
                                        funcionario.id(),
                                        funcionario.nombre(),
                                        funcionario.apellido()
                                )
                        ),
                        socio.id(),
                        funcionario.id(),
                        fecha
                )
                .stream()
                .findFirst();
    }

    public record Socio(Long id, String ci, String nombre, String apellido) {
    }

    public record Funcionario(
            Long id,
            String ci,
            String nombre,
            String apellido
    ) {
    }
}
