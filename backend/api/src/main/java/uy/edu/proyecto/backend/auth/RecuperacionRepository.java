package uy.edu.proyecto.backend.auth;

import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class RecuperacionRepository {

    private final JdbcTemplate jdbcTemplate;

    public RecuperacionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Cuenta habilitada y con primer ingreso completado para esa CI y acceso.
     * FOR UPDATE serializa solicitudes repetidas o concurrentes (RF-05).
     */
    public Optional<CuentaRecuperacion> buscarCuentaActiva(
            String ci,
            String acceso
    ) {
        return buscarCuenta(ci, acceso, true);
    }

    /** Cuenta habilitada que todavia no completo el primer ingreso. */
    public Optional<CuentaRecuperacion> buscarCuentaPendiente(
            String ci,
            String acceso
    ) {
        return buscarCuenta(ci, acceso, false);
    }

    private Optional<CuentaRecuperacion> buscarCuenta(
            String ci,
            String acceso,
            boolean activada
    ) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.correo, p.nombre
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.ci = ?
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = ?
                          AND (
                              (? = 'SOCIO' AND c.rol = 'SOCIO')
                              OR (
                                  ? = 'EMPLEADO'
                                  AND c.rol IN ('FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR')
                              )
                          )
                        FOR UPDATE OF c
                        """,
                        (rs, rowNum) -> new CuentaRecuperacion(
                                rs.getLong("id_cuenta"),
                                rs.getString("correo"),
                                rs.getString("nombre")
                        ),
                        ci,
                        activada,
                        acceso,
                        acceso
                )
                .stream()
                .findFirst();
    }

    /** Cuando se creo el enlace de recuperacion vigente mas reciente. */
    public Optional<OffsetDateTime> ultimoEnlaceVigenteCreadoEn(Long idCuenta) {
        return jdbcTemplate.query(
                        """
                        SELECT creado_en
                        FROM public.enlace_cuenta
                        WHERE id_cuenta = ?
                          AND tipo = 'RECUPERACION'
                          AND usado_en IS NULL
                          AND vence_en > CURRENT_TIMESTAMP
                        ORDER BY creado_en DESC
                        LIMIT 1
                        """,
                        (rs, rowNum) -> rs.getObject(
                                "creado_en", OffsetDateTime.class),
                        idCuenta
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
                  AND tipo = 'RECUPERACION'
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
                VALUES (?, 'RECUPERACION', ?, ?)
                """,
                idCuenta,
                tokenHash,
                venceEn
        );
    }

    /** Consulta las mismas condiciones que completarConEnlace, sin consumir ni bloquear. */
    public boolean existeEnlaceVigente(String tokenHash) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject(
                """
                SELECT EXISTS (
                    SELECT 1
                    FROM public.enlace_cuenta e
                    JOIN public.cuenta c ON c.id_cuenta = e.id_cuenta
                    WHERE e.token_hash = ?
                      AND e.tipo = 'RECUPERACION'
                      AND e.usado_en IS NULL
                      AND e.vence_en > CURRENT_TIMESTAMP
                      AND c.habilitada = TRUE
                      AND c.primer_ingreso_completado = TRUE
                )
                """,
                Boolean.class,
                tokenHash
        ));
    }

    /**
     * Consume el enlace y registra la contrasena nueva en la misma
     * transaccion. Rechaza enlaces inexistentes, vencidos, ya usados o de
     * cuentas inactivadas o sin activar, sin distinguir el motivo.
     */
    public Optional<Long> completarConEnlace(
            String tokenHash,
            String passwordHash
    ) {
        Optional<Long> idCuenta = jdbcTemplate.query(
                        """
                        UPDATE public.enlace_cuenta e
                        SET usado_en = CURRENT_TIMESTAMP
                        FROM public.cuenta c
                        WHERE e.token_hash = ?
                          AND e.tipo = 'RECUPERACION'
                          AND e.usado_en IS NULL
                          AND e.vence_en > CURRENT_TIMESTAMP
                          AND c.id_cuenta = e.id_cuenta
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = TRUE
                        RETURNING e.id_cuenta
                        """,
                        (rs, rowNum) -> rs.getLong("id_cuenta"),
                        tokenHash
                )
                .stream()
                .findFirst();

        idCuenta.ifPresent(id -> jdbcTemplate.update(
                """
                UPDATE public.cuenta
                SET contrasena_hash = ?
                WHERE id_cuenta = ?
                """,
                passwordHash,
                id
        ));

        return idCuenta;
    }

    public record CuentaRecuperacion(
            Long id,
            String correo,
            String nombre
    ) {
    }
}
