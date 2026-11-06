package uy.edu.proyecto.backend.auth;

import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class PrimerIngresoRepository {

    private final JdbcTemplate jdbcTemplate;

    public PrimerIngresoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<CuentaPendiente> buscarCuentaPendiente(
            String ci,
            String acceso
    ) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.correo, p.nombre
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.ci = ?
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = FALSE
                          AND (
                              (? = 'SOCIO' AND c.rol = 'SOCIO')
                              OR (
                                  ? = 'EMPLEADO'
                                  AND c.rol IN ('FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR')
                              )
                          )
                        FOR UPDATE OF c
                        """,
                        (rs, rowNum) -> new CuentaPendiente(
                                rs.getLong("id_cuenta"),
                                rs.getString("correo"),
                                rs.getString("nombre")
                        ),
                        ci,
                        acceso,
                        acceso
                )
                .stream()
                .findFirst();
    }

    public Optional<CuentaPendiente> buscarCuentaActiva(
            String ci,
            String acceso
    ) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.correo, p.nombre
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.ci = ?
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = TRUE
                          AND (
                              (? = 'SOCIO' AND c.rol = 'SOCIO')
                              OR (
                                  ? = 'EMPLEADO'
                                  AND c.rol IN ('FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR')
                              )
                          )
                        FOR UPDATE OF c
                        """,
                        (rs, rowNum) -> new CuentaPendiente(
                                rs.getLong("id_cuenta"),
                                rs.getString("correo"),
                                rs.getString("nombre")
                        ),
                        ci,
                        acceso,
                        acceso
                )
                .stream()
                .findFirst();
    }

    public void invalidarEnlacesPendientes(Long idCuenta) {
        jdbcTemplate.update(
                """
                UPDATE public.enlace_cuenta
                SET usado_en = CURRENT_TIMESTAMP
                WHERE id_cuenta = ?
                  AND tipo = 'PRIMER_INGRESO'
                  AND usado_en IS NULL
                """,
                idCuenta
        );
    }

    public void crearEnlace(
            Long idCuenta,
            String tokenHash,
            OffsetDateTime venceEn
    ) {
        jdbcTemplate.update(
                """
                INSERT INTO public.enlace_cuenta
                    (id_cuenta, tipo, token_hash, vence_en)
                VALUES (?, 'PRIMER_INGRESO', ?, ?)
                """,
                idCuenta,
                tokenHash,
                venceEn
        );
    }

    /** Consulta las mismas condiciones que activarConEnlace, sin consumir ni bloquear. */
    public boolean existeEnlaceVigente(String tokenHash) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.enlace_cuenta e
                    JOIN public.cuenta c ON c.id_cuenta = e.id_cuenta
                    WHERE e.token_hash = ?
                      AND e.tipo = 'PRIMER_INGRESO'
                      AND e.usado_en IS NULL
                      AND e.vence_en > CURRENT_TIMESTAMP
                      AND c.habilitada = TRUE
                      AND c.primer_ingreso_completado = FALSE
                )
                """,
                Boolean.class,
                tokenHash
        ));
    }

    public Optional<CuentaActivadaResponse> activarConEnlace(
            String tokenHash,
            String direccion,
            String telefono1,
            String telefono2,
            String passwordHash
    ) {
        Optional<Long> idCuenta = jdbcTemplate.query(
                        """
                        UPDATE public.enlace_cuenta e
                        SET usado_en = CURRENT_TIMESTAMP
                        FROM public.cuenta c
                        WHERE e.token_hash = ?
                          AND e.tipo = 'PRIMER_INGRESO'
                          AND e.usado_en IS NULL
                          AND e.vence_en > CURRENT_TIMESTAMP
                          AND c.id_cuenta = e.id_cuenta
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = FALSE
                        RETURNING e.id_cuenta
                        """,
                        (rs, rowNum) -> rs.getLong("id_cuenta"),
                        tokenHash
                )
                .stream()
                .findFirst();

        if (idCuenta.isEmpty()) {
            return Optional.empty();
        }

        return jdbcTemplate.query(
                        """
                        UPDATE public.cuenta AS c
                        SET direccion = ?,
                            telefono_1 = ?,
                            telefono_2 = ?,
                            contrasena_hash = ?,
                            primer_ingreso_completado = TRUE
                        FROM public.persona p
                        WHERE c.id_cuenta = ?
                          AND c.ci = p.ci
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = FALSE
                        RETURNING c.id_cuenta,
                                  c.ci,
                                  p.nombre,
                                  p.apellido,
                                  c.rol,
                                  c.habilitada,
                                  c.primer_ingreso_completado
                        """,
                        (rs, rowNum) -> new CuentaActivadaResponse(
                                rs.getLong("id_cuenta"),
                                rs.getString("ci"),
                                rs.getString("nombre"),
                                rs.getString("apellido"),
                                rs.getString("rol"),
                                rs.getBoolean("habilitada") ? "ACTIVA" : "INACTIVA",
                                rs.getBoolean("primer_ingreso_completado")
                        ),
                        direccion,
                        telefono1,
                        telefono2,
                        passwordHash,
                        idCuenta.get()
                )
                .stream()
                .findFirst();
    }

    public record CuentaPendiente(
            Long id,
            String correo,
            String nombre
    ) {
    }
}
