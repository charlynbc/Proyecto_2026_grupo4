package uy.edu.proyecto.backend.dispositivo;

import java.time.OffsetDateTime;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class DispositivoRepository {

    private final JdbcTemplate jdbcTemplate;

    public DispositivoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Registra el token para el socio en una sola sentencia. Si el token ya existia
     * (del mismo socio, de otro o deshabilitado) pasa a ser del socio y queda habilitado;
     * registrado_en solo cambia si hubo reasignacion o rehabilitacion. xmax = 0 solo en
     * las filas recien insertadas: distingue crear (201) de actualizar (200).
     */
    public DispositivoRegistro registrar(Long socioId, String token) {
        return jdbcTemplate.queryForObject(
                """
                INSERT INTO public.dispositivo_push (id_socio, token)
                VALUES (?, ?)
                ON CONFLICT (token) DO UPDATE
                SET id_socio = EXCLUDED.id_socio,
                    habilitado = true,
                    registrado_en = CASE
                        WHEN dispositivo_push.id_socio <> EXCLUDED.id_socio
                          OR NOT dispositivo_push.habilitado
                        THEN CURRENT_TIMESTAMP
                        ELSE dispositivo_push.registrado_en
                    END
                RETURNING id_dispositivo, habilitado, registrado_en, (xmax = 0) AS creado
                """,
                (rs, rowNum) -> new DispositivoRegistro(
                        new DispositivoDTO(
                                rs.getLong("id_dispositivo"),
                                rs.getBoolean("habilitado"),
                                rs.getObject("registrado_en", OffsetDateTime.class)
                        ),
                        rs.getBoolean("creado")
                ),
                socioId,
                token
        );
    }

    /** Solo deshabilita si el token es del socio. Nunca borra: envio_notificacion lo referencia. */
    public int deshabilitar(Long socioId, String token) {
        return jdbcTemplate.update(
                """
                UPDATE public.dispositivo_push
                SET habilitado = false
                WHERE token = ? AND id_socio = ?
                """,
                token,
                socioId
        );
    }
}
