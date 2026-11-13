package uy.edu.proyecto.backend.usuario;

import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class DatosPersonalesRepository {

    private final JdbcTemplate jdbcTemplate;

    public DatosPersonalesRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<DatosPersonalesResponse> buscarDatos(long idCuenta) {
        return jdbcTemplate.query(
                        """
                        SELECT c.id_cuenta, c.ci, p.nombre, p.apellido, c.rol, c.correo,
                               c.telefono_1, c.telefono_2, c.direccion
                        FROM public.cuenta c
                        JOIN public.persona p ON p.ci = c.ci
                        WHERE c.id_cuenta = ?
                        """,
                        (rs, rowNum) -> new DatosPersonalesResponse(
                                rs.getLong("id_cuenta"),
                                rs.getString("ci"),
                                rs.getString("nombre"),
                                rs.getString("apellido"),
                                rs.getString("rol"),
                                rs.getString("correo"),
                                null,
                                rs.getString("telefono_1"),
                                rs.getString("telefono_2"),
                                rs.getString("direccion")
                        ),
                        idCuenta
                )
                .stream()
                .findFirst();
    }

    /** Correo nuevo del enlace CAMBIO_CORREO vigente mas reciente, si hay. */
    public Optional<String> buscarCorreoPendiente(long idCuenta) {
        return jdbcTemplate.query(
                        """
                        SELECT correo_nuevo
                        FROM public.enlace_cuenta
                        WHERE id_cuenta = ?
                          AND tipo = 'CAMBIO_CORREO'
                          AND usado_en IS NULL
                          AND vence_en > CURRENT_TIMESTAMP
                        ORDER BY creado_en DESC
                        LIMIT 1
                        """,
                        (rs, rowNum) -> rs.getString("correo_nuevo"),
                        idCuenta
                )
                .stream()
                .findFirst();
    }

    /**
     * Bloquea la fila de la cuenta (FOR UPDATE) y devuelve sus datos de
     * contacto actuales. Solo cuentas habilitadas: una inactivada no puede
     * editar sus datos.
     */
    public Optional<ContactoCuenta> bloquearCuentaHabilitada(long idCuenta) {
        return jdbcTemplate.query(
                        """
                        SELECT correo, direccion, telefono_1, telefono_2
                        FROM public.cuenta
                        WHERE id_cuenta = ?
                          AND habilitada = TRUE
                        FOR UPDATE
                        """,
                        (rs, rowNum) -> new ContactoCuenta(
                                rs.getString("correo"),
                                rs.getString("direccion"),
                                rs.getString("telefono_1"),
                                rs.getString("telefono_2")
                        ),
                        idCuenta
                )
                .stream()
                .findFirst();
    }

    public void actualizarContacto(
            long idCuenta,
            String direccion,
            String telefono1,
            String telefono2
    ) {
        jdbcTemplate.update(
                """
                UPDATE public.cuenta
                SET direccion = ?,
                    telefono_1 = ?,
                    telefono_2 = ?
                WHERE id_cuenta = ?
                """,
                direccion,
                telefono1,
                telefono2,
                idCuenta
        );
    }

    public void invalidarEnlacesCambioCorreo(long idCuenta) {
        jdbcTemplate.update(
                """
                UPDATE public.enlace_cuenta
                SET usado_en = CURRENT_TIMESTAMP
                WHERE id_cuenta = ?
                  AND tipo = 'CAMBIO_CORREO'
                  AND usado_en IS NULL
                """,
                idCuenta
        );
    }

    public void crearEnlaceCambioCorreo(
            long idCuenta,
            String tokenHash,
            String correoNuevo,
            OffsetDateTime venceEn
    ) {
        jdbcTemplate.update(
                """
                INSERT INTO public.enlace_cuenta
                    (id_cuenta, tipo, token_hash, correo_nuevo, vence_en)
                VALUES (?, 'CAMBIO_CORREO', ?, ?, ?)
                """,
                idCuenta,
                tokenHash,
                correoNuevo,
                venceEn
        );
    }

    /**
     * Consume el enlace y aplica el correo nuevo en la misma transaccion.
     * Rechaza enlaces inexistentes, vencidos, ya usados o de cuentas
     * inactivadas, sin distinguir el motivo.
     */
    public Optional<Long> confirmarCambioCorreo(String tokenHash) {
        record Enlace(Long idCuenta, String correoNuevo) {
        }

        Optional<Enlace> enlace = jdbcTemplate.query(
                        """
                        UPDATE public.enlace_cuenta e
                        SET usado_en = CURRENT_TIMESTAMP
                        FROM public.cuenta c
                        WHERE e.token_hash = ?
                          AND e.tipo = 'CAMBIO_CORREO'
                          AND e.usado_en IS NULL
                          AND e.vence_en > CURRENT_TIMESTAMP
                          AND c.id_cuenta = e.id_cuenta
                          AND c.habilitada = TRUE
                        RETURNING e.id_cuenta, e.correo_nuevo
                        """,
                        (rs, rowNum) -> new Enlace(
                                rs.getLong("id_cuenta"),
                                rs.getString("correo_nuevo")
                        ),
                        tokenHash
                )
                .stream()
                .findFirst();

        enlace.ifPresent(e -> jdbcTemplate.update(
                """
                UPDATE public.cuenta
                SET correo = ?
                WHERE id_cuenta = ?
                """,
                e.correoNuevo(),
                e.idCuenta()
        ));

        return enlace.map(Enlace::idCuenta);
    }

    public record ContactoCuenta(
            String correo,
            String direccion,
            String telefono1,
            String telefono2
    ) {
    }
}
