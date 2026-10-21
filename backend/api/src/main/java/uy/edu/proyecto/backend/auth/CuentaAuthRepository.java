package uy.edu.proyecto.backend.auth;

import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class CuentaAuthRepository {

    private final JdbcTemplate jdbcTemplate;

    public CuentaAuthRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<CuentaAutenticacion> buscarParaLogin(
            String ci,
            String acceso
    ) {
        return jdbcTemplate.query(
                        """
                        SELECT
                            c.id_cuenta,
                            p.nombre,
                            p.apellido,
                            c.contrasena_hash,
                            c.rol
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.ci = ?
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = TRUE
                          AND c.contrasena_hash IS NOT NULL
                          AND (
                              (? = 'SOCIO' AND c.rol = 'SOCIO')
                              OR (
                                  ? = 'EMPLEADO'
                                  AND c.rol IN ('FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR')
                              )
                          )
                        """,
                        (rs, rowNum) -> new CuentaAutenticacion(
                                rs.getLong("id_cuenta"),
                                rs.getString("nombre"),
                                rs.getString("apellido"),
                                rs.getString("contrasena_hash"),
                                rs.getString("rol")
                        ),
                        ci,
                        acceso,
                        acceso
                )
                .stream()
                .findFirst();
    }

    public Optional<CuentaAutenticacion> buscarHabilitadaPorId(Long idCuenta) {
        return jdbcTemplate.query(
                        """
                        SELECT
                            c.id_cuenta,
                            p.nombre,
                            p.apellido,
                            c.contrasena_hash,
                            c.rol
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.id_cuenta = ?
                          AND c.habilitada = TRUE
                          AND c.primer_ingreso_completado = TRUE
                          AND c.contrasena_hash IS NOT NULL
                        """,
                        (rs, rowNum) -> new CuentaAutenticacion(
                                rs.getLong("id_cuenta"),
                                rs.getString("nombre"),
                                rs.getString("apellido"),
                                rs.getString("contrasena_hash"),
                                rs.getString("rol")
                        ),
                        idCuenta
                )
                .stream()
                .findFirst();
    }

    public record CuentaAutenticacion(
            Long id,
            String nombre,
            String apellido,
            String passwordHash,
            String rol
    ) {
    }
}
